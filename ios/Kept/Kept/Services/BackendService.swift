import Foundation

struct AuthSession: Equatable {
    var userId: UUID
    var email: String
}

/// Everything the app needs from a backend. `SupabaseBackendService` is the real
/// implementation; `MockBackendService` is an in-memory stand-in seeded with the same
/// demo data as kept.html, used for SwiftUI previews and for running the app before
/// Supabase credentials are configured.
protocol BackendService {
    // Auth — phone + SMS code, matching Hinge: no passwords anywhere.
    func currentSession() async throws -> AuthSession?
    func requestOTP(phone: String) async throws
    func verifyOTP(phone: String, code: String) async throws -> AuthSession
    func signOut() async throws
    func deleteAccount(userId: UUID) async throws

    // Profile
    func fetchProfile(userId: UUID) async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> URL

    // Habits
    func fetchHabits(userId: UUID) async throws -> [Habit]
    func createHabit(_ habit: Habit, userId: UUID) async throws
    func updateHabit(_ habit: Habit) async throws
    func deleteHabit(id: UUID) async throws
    func setCheckIn(habitId: UUID, userId: UUID, day: Date, note: String?, checkedIn: Bool, status: String) async throws
    /// Separate from setCheckIn on purpose: photos are attached after the row already
    /// exists (an UPDATE targeting habit_id+day), not folded into the upsert payload —
    /// keeps the two concerns independent so editing a note can never accidentally clobber
    /// a photo that's already there, or vice versa.
    func setCheckInPhotos(habitId: UUID, userId: UUID, day: Date, photoURLs: [String]) async throws
    func uploadCheckInPhoto(userId: UUID, imageData: Data) async throws -> URL

    // Circle
    func fetchCircleMembers(userId: UUID) async throws -> [CircleMember]
    func fetchPendingInvites(userId: UUID) async throws -> [PendingInvite]
    func fetchCircleFeed(userId: UUID) async throws -> [CircleFeedItem]
    func fetchContacts(userId: UUID) async throws -> [Contact]
    func sendInvite(userId: UUID, contact: Contact) async throws
    func cancelInvite(id: UUID) async throws
    func removeMember(id: UUID) async throws
    func acceptInvite(inviterId: UUID, accepterId: UUID) async throws
    func registerPushToken(userId: UUID, token: String) async throws
    func notifyInviteAccepted(inviterId: UUID, accepterName: String) async throws
    func sendReaction(feedItemId: UUID, userId: UUID, emoji: String) async throws
    func sendNudge(userId: UUID, memberId: UUID, day: Date) async throws
    func addComment(feedItemId: UUID, userId: UUID, text: String, photoURL: String?) async throws
    func reportCheckIn(checkInId: UUID, reporterId: UUID, reportedUserId: UUID, reason: String) async throws
    func blockUser(blockerId: UUID, blockedId: UUID) async throws

    // Notifications
    func fetchNotificationSettings(userId: UUID) async throws -> NotificationSettings
    func updateNotificationSettings(_ settings: NotificationSettings, userId: UUID) async throws

    // Groups — public/private location-based communities around one shared goal.
    func fetchMyGroups(userId: UUID) async throws -> [HabitGroup]
    func searchPublicGroups(query: String) async throws -> [HabitGroup]
    func fetchGroup(byInviteToken token: String) async throws -> HabitGroup?
    func createGroup(_ group: HabitGroup) async throws
    func joinGroup(groupId: UUID, userId: UUID) async throws
    func leaveGroup(groupId: UUID, userId: UUID) async throws
    func fetchGroupMembers(groupId: UUID) async throws -> [GroupMemberInfo]
    func fetchGroupFeed(groupId: UUID) async throws -> [GroupCheckIn]
    func logGroupCheckIn(groupId: UUID, userId: UUID, amount: Double, note: String?, day: Date) async throws
}
