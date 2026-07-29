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
        // Only 'done' rows count as history — a 'missed' (down day) row is a real post
        // but was never a completed day, so it must never feed streaks or Home's dots.
        let checkInRows: [CheckInRow] = try await client.from("check_ins")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "done")
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

    func setCheckIn(habitId: UUID, userId: UUID, day: Date, note: String?, checkedIn: Bool, status: String) async throws {
        if checkedIn {
            struct Upsert: Codable {
                var habit_id: UUID
                var user_id: UUID
                var logical_day: Date
                var note: String?
                var status: String
            }
            try await client.from("check_ins")
                .upsert(Upsert(habit_id: habitId, user_id: userId, logical_day: day, note: note, status: status),
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
        // Two plain queries joined client-side rather than one PostgREST relational-embed
        // query — circle_members.member_id and profiles.id are both FKs to auth.users
        // rather than one being a direct FK to the other, which is the case PostgREST's
        // automatic relationship detection doesn't reliably handle.
        struct MemberRow: Codable { var id: UUID; var member_id: UUID }
        let memberRows: [MemberRow] = try await client.from("circle_members")
            .select("id, member_id")
            .eq("owner_id", value: userId)
            .execute()
            .value
        guard !memberRows.isEmpty else { return [] }

        struct ProfileRow: Codable { var id: UUID; var name: String }
        let profiles: [ProfileRow] = try await client.from("profiles")
            .select("id, name")
            .in("id", values: memberRows.map(\.member_id))
            .execute()
            .value

        struct CountRow: Codable { var member_id: UUID; var open_habit_count: Int }
        let counts: [CountRow] = try await client
            .rpc("circle_open_habit_counts", params: ["p_owner": userId])
            .execute()
            .value

        return memberRows.enumerated().compactMap { index, row in
            guard let profile = profiles.first(where: { $0.id == row.member_id }) else { return nil }
            let count = counts.first(where: { $0.member_id == row.member_id })?.open_habit_count ?? 0
            return CircleMember(id: row.id, name: profile.name, avatarSeed: index, openHabitCount: count)
        }
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

    /// Covers everyone who *has* checked in today — friends who haven't yet (the ones
    /// Nudge targets) aren't included here yet. That's a genuinely different query shape
    /// (circle members minus who's already checked in, per open habit) with real product
    /// ambiguity around what happens when someone has multiple Open habits, so it's left
    /// as a deliberate follow-up rather than guessed at here.
    func fetchCircleFeed(userId: UUID) async throws -> [CircleFeedItem] {
        // check_ins_circle_select_open_today already restricts what's visible to exactly
        // today's Open, audience-visible, non-blocked check-ins from circle members — the
        // owner_all policy would also return the caller's own full history, so excluding
        // user_id = userId here is what keeps this to *friends'* posts only ("mine" is
        // built separately in AppModel.circleFeed, from local habit state).
        struct FeedCheckInRow: Codable {
            var id: UUID
            var user_id: UUID
            var habit_id: UUID
            var note: String?
            var created_at: Date
            var status: String
        }
        let rows: [FeedCheckInRow] = try await client.from("check_ins")
            .select("id, user_id, habit_id, note, created_at, status")
            .neq("user_id", value: userId)
            .execute()
            .value
        guard !rows.isEmpty else { return [] }

        let checkInIds = rows.map(\.id)
        struct ProfileRow: Codable { var id: UUID; var name: String }
        let authorProfiles: [ProfileRow] = try await client.from("profiles")
            .select("id, name")
            .in("id", values: Array(Set(rows.map(\.user_id))))
            .execute()
            .value

        struct ReactionRow: Codable { var check_in_id: UUID; var user_id: UUID; var emoji: String }
        let reactionRows: [ReactionRow] = try await client.from("reactions")
            .select("check_in_id, user_id, emoji")
            .in("check_in_id", values: checkInIds)
            .execute()
            .value

        struct CommentRow: Codable { var id: UUID; var check_in_id: UUID; var user_id: UUID; var text: String; var created_at: Date }
        let commentRows: [CommentRow] = try await client.from("comments")
            .select("id, check_in_id, user_id, text, created_at")
            .in("check_in_id", values: checkInIds)
            .execute()
            .value
        let commentAuthorIds = Array(Set(commentRows.map(\.user_id)))
        let commentAuthorProfiles: [ProfileRow] = commentAuthorIds.isEmpty ? [] : try await client.from("profiles")
            .select("id, name")
            .in("id", values: commentAuthorIds)
            .execute()
            .value

        // Only readable at all because of habits_circle_select_if_checkin_visible_today,
        // which mirrors the check-in visibility conditions exactly — the post shouldn't
        // just show a streak and a note with no idea what habit it's even about.
        struct HabitInfoRow: Codable { var id: UUID; var name: String; var goal_duration_days: Int?; var created_at: Date }
        let habitInfo: [HabitInfoRow] = try await client.from("habits")
            .select("id, name, goal_duration_days, created_at")
            .in("id", values: Array(Set(rows.map(\.habit_id))))
            .execute()
            .value

        var items: [CircleFeedItem] = []
        for (index, row) in rows.enumerated() {
            let authorName = authorProfiles.first(where: { $0.id == row.user_id })?.name ?? "Someone"
            let myReaction = reactionRows.first { $0.check_in_id == row.id && $0.user_id == userId }?.emoji

            var counts: [String: Int] = [:]
            for reaction in reactionRows where reaction.check_in_id == row.id {
                counts[reaction.emoji, default: 0] += 1
            }
            let reactions = counts.map { ReactionSummary(emoji: $0.key, count: $0.value) }

            let comments = commentRows
                .filter { $0.check_in_id == row.id }
                .sorted { $0.created_at < $1.created_at }
                .map { comment in
                    Comment(
                        id: comment.id,
                        authorName: commentAuthorProfiles.first(where: { $0.id == comment.user_id })?.name ?? "Someone",
                        text: comment.text,
                        postedAt: comment.created_at
                    )
                }

            // Falls back to 1 (this check-in alone) rather than propagating the error —
            // a friend's post showing a slightly-off streak number is a much smaller
            // problem than the whole feed failing to load because one RPC call hiccuped.
            let streakValue: Int? = try? await client
                .rpc("habit_streak_count", params: ["p_habit_id": row.habit_id])
                .execute()
                .value
            let streak = streakValue ?? (row.status == "done" ? 1 : 0)
            let habit = habitInfo.first(where: { $0.id == row.habit_id })
            let dayNumber = habit?.goal_duration_days.map { goal -> Int in
                let daysSinceStart = max(1, Calendar.current.dateComponents([.day], from: habit!.created_at, to: Date()).day.map { $0 + 1 } ?? 1)
                return min(daysSinceStart, goal)
            }

            items.append(CircleFeedItem(
                id: row.id,
                authorId: row.user_id,
                authorName: authorName,
                avatarSeed: index,
                isMine: false,
                habitId: row.habit_id,
                habitName: habit?.name,
                note: row.note,
                timeLabel: relativeTimeLabel(row.created_at),
                streakCount: streak,
                goalDurationDays: habit?.goal_duration_days,
                dayNumber: dayNumber,
                status: row.status == "missed" ? .missed : .done,
                hasCheckedInToday: true,
                reactions: reactions,
                myReactionEmoji: myReaction,
                comments: comments
            ))
        }
        return items
    }

    private func relativeTimeLabel(_ date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "checked in \(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "checked in \(hours)h ago" }
        return "checked in today"
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

    /// Mutual: accepting an invite links both directions, so the two people can see each
    /// other's Open habits, matching how the rest of Circle assumes membership works.
    func acceptInvite(inviterId: UUID, accepterId: UUID) async throws {
        struct MemberInsert: Codable {
            var owner_id: UUID
            var member_id: UUID
        }
        try await client.from("circle_members")
            .upsert(
                [MemberInsert(owner_id: inviterId, member_id: accepterId),
                 MemberInsert(owner_id: accepterId, member_id: inviterId)],
                onConflict: "owner_id,member_id"
            )
            .execute()
    }

    func registerPushToken(userId: UUID, token: String) async throws {
        struct TokenUpsert: Codable {
            var user_id: UUID
            var device_token: String
        }
        try await client.from("push_tokens")
            .upsert(TokenUpsert(user_id: userId, device_token: token), onConflict: "user_id,device_token")
            .execute()
    }

    /// Reads the inviter's device token(s) and sends the actual APNs push from a
    /// service-role Edge Function — the client can't read another user's push_tokens row
    /// directly (RLS is owner-only), same reasoning as delete-account needing the service
    /// role for cross-user work.
    func notifyInviteAccepted(inviterId: UUID, accepterName: String) async throws {
        struct Payload: Encodable {
            var inviter_id: String
            var accepter_name: String
        }
        let payload = Payload(inviter_id: inviterId.uuidString, accepter_name: accepterName)
        let body = try JSONEncoder().encode(payload)
        _ = try await client.functions.invoke("notify-invite-accepted", options: FunctionInvokeOptions(body: body))
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

    func reportCheckIn(checkInId: UUID, reporterId: UUID, reportedUserId: UUID, reason: String) async throws {
        struct ReportInsert: Codable {
            var reporter_id: UUID
            var reported_user_id: UUID
            var check_in_id: UUID
            var reason: String
        }
        try await client.from("reports")
            .insert(ReportInsert(reporter_id: reporterId, reported_user_id: reportedUserId, check_in_id: checkInId, reason: reason))
            .execute()
    }

    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        struct BlockInsert: Codable {
            var blocker_id: UUID
            var blocked_id: UUID
        }
        try await client.from("blocks")
            .insert(BlockInsert(blocker_id: blockerId, blocked_id: blockedId))
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
