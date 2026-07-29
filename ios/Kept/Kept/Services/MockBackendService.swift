import Foundation

/// In-memory backend seeded with the same demo data as kept.html. Used for SwiftUI
/// previews and as the default backend until Supabase credentials are configured in
/// SupabaseConfig.swift, so the app is runnable end-to-end from a fresh clone.
actor MockBackendService: BackendService {
    static let demoUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var profile: UserProfile
    private var habits: [Habit]
    private var members: [CircleMember]
    private var invites: [PendingInvite]
    private var contacts: [Contact]
    private var notificationSettings = NotificationSettings()
    private var reactionsByCheckIn: [UUID: [String: Int]] = [:]
    private var groups: [HabitGroup] = []
    private var groupMemberIds: [UUID: [UUID]] = [:]
    private var groupCheckIns: [GroupCheckIn] = []
    private var isSignedIn = false
    /// Fixed code accepted in place of a real SMS — there's no Twilio/etc. configured yet
    /// in mock mode, so this is what VerifyCodeView tells you to type when testing locally.
    static let testVerificationCode = "123456"

    init() {
        let calendar = DayCalendar()
        let today = calendar.logicalDay(for: Date())
        func days(back: [Int]) -> [Date] {
            back.map { Calendar.current.date(byAdding: .day, value: -$0, to: today)! }
        }

        profile = UserProfile(id: MockBackendService.demoUserId, name: "Tanaz D.", handle: "tanaz93",
                               bio: "Personal trainer · NYC. Keeping some habits open, some to myself.")

        habits = [
            Habit(name: "Morning Run", visibility: .open,
                  createdAt: Calendar.current.date(byAdding: .day, value: -13, to: today)!,
                  checkInHistory: days(back: Array(0...12))),
            Habit(name: "Drink Water", visibility: .kept,
                  createdAt: Calendar.current.date(byAdding: .day, value: -24, to: today)!,
                  checkInHistory: days(back: Array(1...23))),
            Habit(name: "Journal 5 Min", visibility: .kept,
                  createdAt: Calendar.current.date(byAdding: .day, value: -6, to: today)!,
                  checkInHistory: days(back: Array(1...5))),
            Habit(name: "Gym Before Work", visibility: .open,
                  createdAt: Calendar.current.date(byAdding: .day, value: -30, to: today)!,
                  goalDurationDays: 30,
                  checkInHistory: days(back: Array(1...29))),
        ]

        members = [
            CircleMember(id: UUID(), name: "Bobby", avatarSeed: 1, openHabitCount: 2),
            CircleMember(id: UUID(), name: "Gigi", avatarSeed: 2, openHabitCount: 2),
            CircleMember(id: UUID(), name: "Devon K.", avatarSeed: 3, openHabitCount: 2),
            CircleMember(id: UUID(), name: "Priya S.", avatarSeed: 4, openHabitCount: 2),
        ]
        invites = [PendingInvite(id: UUID(), name: "Rae Whitfield", avatarSeed: 1, invitedAt: Date().addingTimeInterval(-172_800))]
        contacts = [
            Contact(id: UUID(), name: "Simi Gill", avatarSeed: 3),
            Contact(id: UUID(), name: "Marcus T.", avatarSeed: 4),
        ]
    }

    func currentSession() async throws -> AuthSession? {
        isSignedIn ? AuthSession(userId: MockBackendService.demoUserId, email: "") : nil
    }

    func requestOTP(phone: String) async throws {
        // No real SMS provider in mock mode — VerifyCodeView tells the user to type
        // MockBackendService.testVerificationCode instead of waiting for a text.
    }

    func verifyOTP(phone: String, code: String) async throws -> AuthSession {
        guard code == MockBackendService.testVerificationCode else { throw BackendError.invalidCode }
        isSignedIn = true
        return AuthSession(userId: MockBackendService.demoUserId, email: "")
    }

    func signOut() async throws { isSignedIn = false }

    func deleteAccount(userId: UUID) async throws { isSignedIn = false }

    func fetchProfile(userId: UUID) async throws -> UserProfile { profile }

    func updateProfile(_ newProfile: UserProfile) async throws { profile = newProfile }

    /// No real Storage bucket in mock mode, so this writes to the app's own Documents
    /// folder and hands back a file:// URL instead of a fake https one AsyncImage could
    /// never actually load — the previous placeholder URL made it look like photo upload
    /// was silently broken when testing without Supabase configured.
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = directory.appendingPathComponent("avatar-\(userId.uuidString).jpg")
        try imageData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func fetchHabits(userId: UUID) async throws -> [Habit] { habits }

    func createHabit(_ habit: Habit, userId: UUID) async throws { habits.append(habit) }

    func updateHabit(_ habit: Habit) async throws {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index] = habit
    }

    func deleteHabit(id: UUID) async throws {
        habits.removeAll { $0.id == id }
    }

    func setCheckIn(habitId: UUID, userId: UUID, day: Date, note: String?, checkedIn: Bool, status: String) async throws {
        guard let index = habits.firstIndex(where: { $0.id == habitId }) else { return }
        if checkedIn {
            // A "missed" (down day) post never enters checkInHistory — only 'done' rows
            // count toward a streak. AppModel.downDayHabitIds is what actually drives the
            // Circle post for a down day; this mirror just needs to not fake a streak day.
            if status == "done" {
                habits[index].checkIn(on: day)
            }
        } else {
            habits[index].undoCheckIn(on: day)
        }
    }

    /// No real Storage bucket in mock mode, same reasoning as uploadAvatar — writes to
    /// Documents and hands back a real, loadable file:// URL.
    func setCheckInPhotos(habitId: UUID, userId: UUID, day: Date, photoURLs: [String]) async throws {}

    func uploadCheckInPhoto(userId: UUID, imageData: Data) async throws -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = directory.appendingPathComponent("post-photo-\(UUID().uuidString).jpg")
        try imageData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func fetchCircleMembers(userId: UUID) async throws -> [CircleMember] { members }

    func fetchPendingInvites(userId: UUID) async throws -> [PendingInvite] { invites }

    func fetchCircleFeed(userId: UUID) async throws -> [CircleFeedItem] { [] }

    func fetchContacts(userId: UUID) async throws -> [Contact] { contacts }

    func sendInvite(userId: UUID, contact: Contact) async throws {
        contacts.removeAll { $0.id == contact.id }
        invites.append(PendingInvite(id: contact.id, name: contact.name, avatarSeed: contact.avatarSeed, invitedAt: Date()))
    }

    func cancelInvite(id: UUID) async throws {
        invites.removeAll { $0.id == id }
    }

    func removeMember(id: UUID) async throws {
        members.removeAll { $0.id == id }
    }

    func acceptInvite(inviterId: UUID, accepterId: UUID) async throws {}
    func registerPushToken(userId: UUID, token: String) async throws {}
    func notifyInviteAccepted(inviterId: UUID, accepterName: String) async throws {}

    func sendReaction(feedItemId: UUID, userId: UUID, emoji: String) async throws {
        reactionsByCheckIn[feedItemId, default: [:]][emoji, default: 0] += 1
    }

    func sendNudge(userId: UUID, memberId: UUID, day: Date) async throws {}

    func addComment(feedItemId: UUID, userId: UUID, text: String, photoURL: String?) async throws {}
    func reportCheckIn(checkInId: UUID, reporterId: UUID, reportedUserId: UUID, reason: String) async throws {}
    func blockUser(blockerId: UUID, blockedId: UUID) async throws {}

    func fetchNotificationSettings(userId: UUID) async throws -> NotificationSettings { notificationSettings }

    func updateNotificationSettings(_ settings: NotificationSettings, userId: UUID) async throws {
        notificationSettings = settings
    }

    // MARK: - Groups

    func fetchMyGroups(userId: UUID) async throws -> [HabitGroup] {
        groups.filter { (groupMemberIds[$0.id] ?? []).contains(userId) }
    }

    func searchPublicGroups(query: String) async throws -> [HabitGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let publicGroups = groups.filter { $0.visibility == .publicGroup }
        guard !trimmed.isEmpty else { return publicGroups }
        return publicGroups.filter {
            $0.name.lowercased().contains(trimmed) || $0.locationLabel.lowercased().contains(trimmed)
        }
    }

    func fetchGroup(byInviteToken token: String) async throws -> HabitGroup? {
        groups.first { $0.inviteToken == token }
    }

    func createGroup(_ group: HabitGroup) async throws {
        groups.append(group)
        groupMemberIds[group.id, default: []].append(group.creatorId)
    }

    func joinGroup(groupId: UUID, userId: UUID) async throws {
        guard var ids = groupMemberIds[groupId] else { return }
        guard !ids.contains(userId) else { return }
        ids.append(userId)
        groupMemberIds[groupId] = ids
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].memberCount = ids.count
        }
    }

    func leaveGroup(groupId: UUID, userId: UUID) async throws {
        groupMemberIds[groupId]?.removeAll { $0 == userId }
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].memberCount = groupMemberIds[groupId]?.count ?? 0
        }
    }

    func fetchGroupMembers(groupId: UUID) async throws -> [GroupMemberInfo] {
        let ids = groupMemberIds[groupId] ?? []
        return ids.enumerated().map { index, id in
            GroupMemberInfo(id: id, name: id == profile.id ? profile.name : "Member", avatarSeed: index)
        }
    }

    func fetchGroupFeed(groupId: UUID, userId: UUID) async throws -> [GroupCheckIn] {
        groupCheckIns.filter { $0.groupId == groupId }.sorted { $0.loggedAt > $1.loggedAt }
    }

    func logGroupCheckIn(groupId: UUID, userId: UUID, amount: Double, note: String?, day: Date, photoURLs: [String]) async throws {
        groupCheckIns.append(GroupCheckIn(
            id: UUID(), groupId: groupId, memberId: userId,
            memberName: userId == profile.id ? profile.name : "Member",
            avatarSeed: 0, amount: amount, note: note, loggedAt: Date(),
            photoURLs: photoURLs.compactMap(URL.init(string:))
        ))
    }

    func addGroupComment(groupCheckInId: UUID, userId: UUID, text: String, photoURL: String?) async throws {
        guard let index = groupCheckIns.firstIndex(where: { $0.id == groupCheckInId }) else { return }
        groupCheckIns[index].comments.append(Comment(
            id: UUID(), authorName: userId == profile.id ? profile.name : "Member",
            text: text, postedAt: Date(), photoURL: photoURL.flatMap(URL.init(string:))
        ))
    }

    func reactToGroupCheckIn(groupCheckInId: UUID, userId: UUID, emoji: String) async throws {
        guard let index = groupCheckIns.firstIndex(where: { $0.id == groupCheckInId }) else { return }
        if let reactionIndex = groupCheckIns[index].reactions.firstIndex(where: { $0.emoji == emoji }) {
            groupCheckIns[index].reactions[reactionIndex].count += 1
        } else {
            groupCheckIns[index].reactions.append(ReactionSummary(emoji: emoji, count: 1))
        }
        groupCheckIns[index].myReactionEmoji = emoji
    }
}
