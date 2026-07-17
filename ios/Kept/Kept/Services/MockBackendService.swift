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

    func uploadAvatar(userId: UUID, imageData: Data) async throws -> URL {
        URL(string: "https://example.com/avatar.jpg")!
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

    func setCheckIn(habitId: UUID, userId: UUID, day: Date, note: String?, checkedIn: Bool) async throws {
        guard let index = habits.firstIndex(where: { $0.id == habitId }) else { return }
        if checkedIn {
            habits[index].checkIn(on: day)
        } else {
            habits[index].undoCheckIn(on: day)
        }
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

    func sendReaction(feedItemId: UUID, userId: UUID, emoji: String) async throws {
        reactionsByCheckIn[feedItemId, default: [:]][emoji, default: 0] += 1
    }

    func sendNudge(userId: UUID, memberId: UUID, day: Date) async throws {}

    func addComment(feedItemId: UUID, userId: UUID, text: String) async throws {}
    func reportCheckIn(checkInId: UUID, reporterId: UUID, reportedUserId: UUID, reason: String) async throws {}
    func blockUser(blockerId: UUID, blockedId: UUID) async throws {}

    func fetchNotificationSettings(userId: UUID) async throws -> NotificationSettings { notificationSettings }

    func updateNotificationSettings(_ settings: NotificationSettings, userId: UUID) async throws {
        notificationSettings = settings
    }
}
