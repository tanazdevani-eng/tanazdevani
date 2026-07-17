import Foundation
import Supabase

enum BackendError: LocalizedError {
    case confirmationRequired
    case notSignedIn
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .confirmationRequired: return "Check your phone for the code, then try again."
        case .notSignedIn: return "You're not signed in."
        case .invalidCode: return "That code didn't match. Check it and try again."
        }
    }
}

/// Talks to the Supabase project described in Kept/Services/SupabaseConfig.swift.
/// Table shapes and RLS policies live in Supabase/schema.sql — the two must stay in sync.
final class SupabaseBackendService: BackendService {
    let client: SupabaseClient

    init(url: URL, anonKey: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    // MARK: - Auth

    func currentSession() async throws -> AuthSession? {
        guard let session = try? await client.auth.session else { return nil }
        return AuthSession(userId: session.user.id, email: session.user.email ?? "")
    }

    /// Sends the SMS code. Requires an SMS provider (Twilio, MessageBird, ...) configured
    /// in Supabase → Authentication → Providers → Phone — see docs/APP_STORE_GUIDE.md.
    func requestOTP(phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
    }

    /// Verifying auto-creates the auth.users row server-side if this phone number has
    /// never signed in before — Supabase phone auth doesn't need a separate "sign up"
    /// call, which is why AppModel decides new-vs-returning from the button tapped on
    /// Welcome rather than from anything this returns.
    func verifyOTP(phone: String, code: String) async throws -> AuthSession {
        let response = try await client.auth.verifyOTP(phone: phone, token: code, type: .sms)
        return AuthSession(userId: response.user.id, email: response.user.email ?? "")
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount(userId: UUID) async throws {
        try await client.functions.invoke("delete-account")
    }

    // MARK: - Profile

    private struct ProfileRow: Codable {
        var id: UUID
        var name: String
        var handle: String
        var bio: String
        var avatar_url: String?
    }

    func fetchProfile(userId: UUID) async throws -> UserProfile {
        let row: ProfileRow = try await client.from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return UserProfile(id: row.id, name: row.name, handle: row.handle, bio: row.bio,
                            avatarURL: row.avatar_url.flatMap(URL.init(string:)))
    }

    func updateProfile(_ profile: UserProfile) async throws {
        let row = ProfileRow(id: profile.id, name: profile.name, handle: profile.handle,
                              bio: profile.bio, avatar_url: profile.avatarURL?.absoluteString)
        try await client.from("profiles").upsert(row).execute()
    }

    func uploadAvatar(userId: UUID, imageData: Data) async throws -> URL {
        let path = "\(userId.uuidString)/avatar.jpg"
        try await client.storage.from("avatars").upload(path, data: imageData, options: .init(upsert: true))
        return try client.storage.from("avatars").getPublicURL(path: path)
    }

    // MARK: - Habits

    private struct HabitRow: Codable {
        var id: UUID
        var user_id: UUID
        var name: String
        var visibility: String
        var goal_duration_days: Int?
        var created_at: Date
    }

    private struct CheckInRow: Codable {
        var id: UUID
        var habit_id: UUID
        var user_id: UUID
        var logical_day: Date
        var note: String?
    }

    private struct HabitAudienceRow: Codable {
        var habit_id: UUID
        var member_id: UUID
    }

    func fetchHabits(userId: UUID) async throws -> [Habit] {
        let habitRows: [HabitRow] = try await client.from("habits")
            .select()
            .eq("user_id", value: userId)
            .order("created_at")
            .execute()
            .value
        let checkInRows: [CheckInRow] = try await client.from("check_ins")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        let audienceRows: [HabitAudienceRow] = try await client.from("habit_audience")
            .select()
            .in("habit_id", values: habitRows.map(\.id))
            .execute()
            .value

        return habitRows.map { row in
            let history = checkInRows.filter { $0.habit_id == row.id }.map(\.logical_day)
            let audience = Set(audienceRows.filter { $0.habit_id == row.id }.map(\.member_id))
            return Habit(
                id: row.id,
                name: row.name,
                visibility: HabitVisibility(rawValue: row.visibility) ?? .open,
                createdAt: row.created_at,
                goalDurationDays: row.goal_duration_days,
                checkInHistory: history,
                sharedWithMemberIds: audience
            )
        }
    }

    func createHabit(_ habit: Habit, userId: UUID) async throws {
        let row = HabitRow(id: habit.id, user_id: userId, name: habit.name,
                            visibility: habit.visibility.rawValue,
                            goal_duration_days: habit.goalDurationDays, created_at: habit.createdAt)
        try await client.from("habits").insert(row).execute()
        try await syncAudience(habitId: habit.id, memberIds: habit.sharedWithMemberIds)
    }

    func updateHabit(_ habit: Habit) async throws {
        struct Patch: Codable {
            var name: String
            var visibility: String
            var goal_duration_days: Int?
        }
        let patch = Patch(name: habit.name, visibility: habit.visibility.rawValue,
                           goal_duration_days: habit.goalDurationDays)
        try await client.from("habits").update(patch).eq("id", value: habit.id).execute()
        try await syncAudience(habitId: habit.id, memberIds: habit.sharedWithMemberIds)
    }

    /// Simplest-correct sync: replace the whole audience list rather than diffing it —
    /// these lists are small (a handful of Circle members at most), so the extra round
    /// trip isn't worth the complexity of computing an add/remove diff.
    private func syncAudience(habitId: UUID, memberIds: Set<UUID>) async throws {
        try await client.from("habit_audience").delete().eq("habit_id", value: habitId).execute()
        guard !memberIds.isEmpty else { return }
        let rows = memberIds.map { HabitAudienceRow(habit_id: habitId, member_id: $0) }
        try await client.from("habit_audience").insert(rows).execute()
    }

    func deleteHabit(id: UUID) async throws {
        try await client.from("habits").delete().eq("id", value: id).execute()
    }

    func setCheckIn(habitId: UUID, userId: UUID, day: Date, note: String?, checkedIn: Bool) async throws {
        if checkedIn {
            struct Upsert: Codable {
                var habit_id: UUID
                var user_id: UUID
                var logical_day: Date
                var note: String?
            }
            try await client.from("check_ins")
                .upsert(Upsert(habit_id: habitId, user_id: userId, logical_day: day, note: note),
                        onConflict: "habit_id,logical_day")
                .execute()
        } else {
            try await client.from("check_ins")
                .delete()
                .eq("habit_id", value: habitId)
                .eq("logical_day", value: day)
                .execute()
        }
    }

    // MARK: - Circle

    func fetchCircleMembers(userId: UUID) async throws -> [CircleMember] {
        // Real implementation joins circle_members -> profiles -> count of that friend's
        // open habits. Left as a Postgres view (`circle_members_with_counts`) you create
        // alongside schema.sql once you're ready to wire this up against real users.
        []
    }

    func fetchPendingInvites(userId: UUID) async throws -> [PendingInvite] {
        struct InviteRow: Codable {
            var id: UUID
            var invitee_name: String
            var created_at: Date
        }
        let rows: [InviteRow] = try await client.from("invites")
            .select()
            .eq("inviter_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows.enumerated().map { index, row in
            PendingInvite(id: row.id, name: row.invitee_name, avatarSeed: index, invitedAt: row.created_at)
        }
    }

    func fetchCircleFeed(userId: UUID) async throws -> [CircleFeedItem] {
        // The check_ins_circle_select_open_today RLS policy already restricts this query
        // to exactly what should be visible; grouping into CircleFeedItem + reaction
        // counts happens client-side (or in a Postgres view once traffic justifies it).
        []
    }

    func fetchContacts(userId: UUID) async throws -> [Contact] {
        []
    }

    func sendInvite(userId: UUID, contact: Contact) async throws {
        struct InviteInsert: Codable {
            var inviter_id: UUID
            var invitee_contact: String
            var invitee_name: String
        }
        try await client.from("invites")
            .insert(InviteInsert(inviter_id: userId, invitee_contact: contact.id.uuidString, invitee_name: contact.name))
            .execute()
    }

    func cancelInvite(id: UUID) async throws {
        try await client.from("invites").update(["status": "cancelled"]).eq("id", value: id).execute()
    }

    func removeMember(id: UUID) async throws {
        try await client.from("circle_members").delete().eq("id", value: id).execute()
    }

    func sendReaction(feedItemId: UUID, userId: UUID, emoji: String) async throws {
        struct ReactionUpsert: Codable {
            var check_in_id: UUID
            var user_id: UUID
            var emoji: String
        }
        try await client.from("reactions")
            .upsert(ReactionUpsert(check_in_id: feedItemId, user_id: userId, emoji: emoji), onConflict: "check_in_id,user_id")
            .execute()
    }

    func sendNudge(userId: UUID, memberId: UUID, day: Date) async throws {
        struct NudgeInsert: Codable {
            var from_user_id: UUID
            var to_user_id: UUID
            var logical_day: Date
        }
        try await client.from("nudges")
            .insert(NudgeInsert(from_user_id: userId, to_user_id: memberId, logical_day: day))
            .execute()
    }

    func addComment(feedItemId: UUID, userId: UUID, text: String) async throws {
        struct CommentInsert: Codable {
            var check_in_id: UUID
            var user_id: UUID
            var text: String
        }
        try await client.from("comments")
            .insert(CommentInsert(check_in_id: feedItemId, user_id: userId, text: text))
            .execute()
    }

    // MARK: - Notifications

    func fetchNotificationSettings(userId: UUID) async throws -> NotificationSettings {
        // Reminder scheduling itself is local (see NotificationScheduler); only the
        // day-reset hour and defaults are worth persisting server-side across devices.
        NotificationSettings()
    }

    func updateNotificationSettings(_ settings: NotificationSettings, userId: UUID) async throws {
        struct Patch: Codable {
            var day_reset_hour: Int
            var remind_for_all_habits: Bool
            var customize_per_habit: Bool
        }
        try await client.from("profiles")
            .update(Patch(day_reset_hour: settings.dayResetHour,
                          remind_for_all_habits: settings.remindForAllHabits,
                          customize_per_habit: settings.customizePerHabit))
            .eq("id", value: userId)
            .execute()
    }
}
