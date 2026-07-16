import Foundation

/// Central app state: habits, Circle, profile, notification settings. Views read this via
/// @EnvironmentObject and call its methods directly rather than going through a
/// ViewModel per screen — for an app this size a single well-organized model is simpler
/// to reason about than a ViewModel per screen, and it's where the visibility-cascade
/// business rules from the spec belong so they can't be forgotten in some screen's local
/// state.
@MainActor
final class AppModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var habits: [Habit] = []
    @Published var circleMembers: [CircleMember] = []
    @Published var pendingInvites: [PendingInvite] = []
    @Published var contacts: [Contact] = []
    @Published var notificationSettings = NotificationSettings()
    @Published var defaultVisibility: HabitVisibility = .open
    @Published var toast: String?
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var selectedTab: RootTab = .home

    /// Demo seed for friends' Circle activity until real multi-user Supabase data is
    /// wired up (fetchCircleFeed returns [] against a fresh project with only you in it).
    @Published var friendFeedItems: [CircleFeedItem]
    /// Today's optional check-in note per habit, shown on the Circle card until undone.
    @Published var todaysNotes: [UUID: String] = [:]

    let storeKit: StoreKitManager
    private let backend: BackendService
    private let scheduler: NotificationScheduler
    private var session: AuthSession?
    private var toastTask: Task<Void, Never>?

    var dayCalendar: DayCalendar { notificationSettings.dayCalendar }
    var isSubscribed: Bool { storeKit.isSubscribed }
    var habitsKeptCount: Int { habits.count }
    var circleCount: Int { circleMembers.count }
    var keptLockCount: Int { habits.filter { $0.visibility == .kept }.count }
    var canAddHabit: Bool { isSubscribed || habits.count < Plan.freeHabitLimit }
    var isNearKeptLockLimit: Bool { !isSubscribed && keptLockCount >= Plan.freeLockLimit }
    var overallStreak: Int { habits.map { $0.streakCount(calendar: dayCalendar) }.max() ?? 0 }

    init(backend: BackendService, storeKit: StoreKitManager, scheduler: NotificationScheduler = NotificationScheduler()) {
        self.backend = backend
        self.storeKit = storeKit
        self.scheduler = scheduler
        self.profile = UserProfile(name: "", handle: "", bio: "")
        self.friendFeedItems = [
            CircleFeedItem(id: UUID(), authorId: UUID(), authorName: "Bobby", avatarSeed: 1, isMine: false,
                           habitId: nil, note: "Gym before 7am. Legs day, barely made it.",
                           timeLabel: "checked in 2h ago", streakCount: 8, hasCheckedInToday: true,
                           reactions: [ReactionSummary(emoji: "❤️", count: 3)], myReactionEmoji: nil),
            CircleFeedItem(id: UUID(), authorId: UUID(), authorName: "Gigi", avatarSeed: 2, isMine: false,
                           habitId: nil, note: "Walked 10k steps on the beginner plan. Day 21 straight.",
                           timeLabel: "hasn't checked in yet today", streakCount: 21, hasCheckedInToday: false,
                           reactions: [ReactionSummary(emoji: "🙌", count: 5)], myReactionEmoji: nil),
        ]
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            var currentSession = try await backend.currentSession()
            if currentSession == nil {
                currentSession = try await backend.signIn(email: "demo@kept.app", password: "demo-password")
            }
            guard let currentSession else { return }
            session = currentSession

            async let profileFetch = backend.fetchProfile(userId: currentSession.userId)
            async let habitsFetch = backend.fetchHabits(userId: currentSession.userId)
            async let membersFetch = backend.fetchCircleMembers(userId: currentSession.userId)
            async let invitesFetch = backend.fetchPendingInvites(userId: currentSession.userId)
            async let contactsFetch = backend.fetchContacts(userId: currentSession.userId)
            async let settingsFetch = backend.fetchNotificationSettings(userId: currentSession.userId)

            profile = try await profileFetch
            habits = try await habitsFetch
            circleMembers = try await membersFetch
            pendingInvites = try await invitesFetch
            contacts = try await contactsFetch
            notificationSettings = try await settingsFetch
            reconcilePerHabitReminders()

            scheduler.requestAuthorizationIfNeeded()
            scheduler.syncReminders(for: habits, settings: notificationSettings)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Habits

    @discardableResult
    func addHabit(name: String, visibility: HabitVisibility, duration: HabitDuration) -> Bool {
        guard canAddHabit else { return false }
        let habit = Habit(name: name, visibility: visibility, goalDurationDays: duration.totalDays)
        habits.append(habit)
        notificationSettings.perHabitReminders.append(
            HabitReminder(habitId: habit.id, habitName: name, time: DateComponents(hour: 7, minute: 0), isOn: true)
        )
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        Task { try? await backend.createHabit(habit, userId: requireUserId()) }
        showToast("\"\(name)\" added")
        return true
    }

    func updateHabit(_ habit: Habit, name: String, visibility: HabitVisibility, duration: HabitDuration) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].name = name
        habits[index].visibility = visibility
        habits[index].duration = duration
        if visibility == .kept {
            todaysNotes.removeValue(forKey: habit.id)
        }
        if let reminderIndex = notificationSettings.perHabitReminders.firstIndex(where: { $0.habitId == habit.id }) {
            notificationSettings.perHabitReminders[reminderIndex].habitName = name
        }
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        Task { try? await backend.updateHabit(habits[index]) }
        showToast("Habit updated")
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        todaysNotes.removeValue(forKey: habit.id)
        notificationSettings.perHabitReminders.removeAll { $0.habitId == habit.id }
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        Task { try? await backend.deleteHabit(id: habit.id) }
        showToast("Habit deleted")
    }

    /// Visibility changes cascade automatically here: the Circle feed is *derived* from
    /// (visibility == .open && checkedInToday), so flipping to Kept makes today's post
    /// disappear on its own with no separate "remove the post" step, and flipping to
    /// Open never exposes past days because the feed only ever looks at today.
    func toggleVisibility(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].visibility = habits[index].visibility == .open ? .kept : .open
        let becameKept = habits[index].visibility == .kept
        if becameKept && habits[index].isCheckedIn(calendar: dayCalendar) {
            showToast("Made private. Pulled from Circle too")
        }
        Task { try? await backend.updateHabit(habits[index]) }
    }

    func checkIn(_ habit: Habit, note: String?) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].checkIn(calendar: dayCalendar)
        if let note, !note.isEmpty {
            todaysNotes[habit.id] = note
        }
        let day = dayCalendar.logicalDay(for: Date())
        Task { try? await backend.setCheckIn(habitId: habit.id, userId: requireUserId(), day: day, note: note, checkedIn: true) }
    }

    func undoCheckIn(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].undoCheckIn(calendar: dayCalendar)
        todaysNotes.removeValue(forKey: habit.id)
        let day = dayCalendar.logicalDay(for: Date())
        Task { try? await backend.setCheckIn(habitId: habit.id, userId: requireUserId(), day: day, note: nil, checkedIn: false) }
        showToast("Check-in undone")
    }

    // MARK: - Circle feed (derived)

    var circleFeed: [CircleFeedItem] {
        let mine: [CircleFeedItem] = habits
            .filter { $0.visibility == .open && $0.isCheckedIn(calendar: dayCalendar) }
            .map { habit in
                CircleFeedItem(
                    id: habit.id,
                    authorId: profile.id,
                    authorName: "You",
                    avatarSeed: 0,
                    isMine: true,
                    habitId: habit.id,
                    note: todaysNotes[habit.id],
                    timeLabel: "just now",
                    streakCount: habit.streakCount(calendar: dayCalendar),
                    hasCheckedInToday: true,
                    reactions: [],
                    myReactionEmoji: nil
                )
            }
        return mine + friendFeedItems
    }

    func reactToFeedItem(_ item: CircleFeedItem, emoji: String) {
        guard let index = friendFeedItems.firstIndex(where: { $0.id == item.id }) else { return }
        var reactions = friendFeedItems[index].reactions
        if let existingIndex = reactions.firstIndex(where: { $0.emoji == emoji }) {
            reactions[existingIndex].count += 1
        } else {
            reactions.append(ReactionSummary(emoji: emoji, count: 1))
        }
        friendFeedItems[index].reactions = reactions
        friendFeedItems[index].myReactionEmoji = emoji
        Task { try? await backend.sendReaction(feedItemId: item.id, userId: requireUserId(), emoji: emoji) }
    }

    /// Nudge is only ever offered on people who haven't checked in today — the caller
    /// (CircleView) already filters for that, this just fires the request.
    func nudge(_ item: CircleFeedItem) {
        showToast("You nudged \(item.authorName)")
        Task { try? await backend.sendNudge(userId: requireUserId(), memberId: item.authorId, day: dayCalendar.logicalDay(for: Date())) }
    }

    // MARK: - Circle management

    func removeMember(_ member: CircleMember) {
        circleMembers.removeAll { $0.id == member.id }
        showToast("\(member.name) removed")
        Task { try? await backend.removeMember(id: member.id) }
    }

    func cancelInvite(_ invite: PendingInvite) {
        pendingInvites.removeAll { $0.id == invite.id }
        showToast("Invite canceled")
        Task { try? await backend.cancelInvite(id: invite.id) }
    }

    func sendInvite(to contact: Contact) {
        contacts.removeAll { $0.id == contact.id }
        pendingInvites.append(PendingInvite(id: contact.id, name: contact.name, avatarSeed: contact.avatarSeed, invitedAt: Date()))
        Task { try? await backend.sendInvite(userId: requireUserId(), contact: contact) }
    }

    // MARK: - Profile & settings

    func toggleDefaultVisibility() {
        defaultVisibility = defaultVisibility == .open ? .kept : .open
        showToast("New habits default to \(defaultVisibility.label)")
    }

    func updateProfile(name: String, handle: String, bio: String) {
        profile.name = name
        profile.handle = handle
        profile.bio = bio
        Task { try? await backend.updateProfile(profile) }
        showToast("Profile updated")
    }

    /// Photos land in Supabase Storage as-is; before shipping, wire a moderation check
    /// (e.g. a Supabase Edge Function calling a vision moderation API) between the upload
    /// and setting avatarURL, per Guideline 1.2 — nothing here blocks that today.
    func uploadAvatar(data: Data) async throws {
        let url = try await backend.uploadAvatar(userId: requireUserId(), imageData: data)
        profile.avatarURL = url
        try? await backend.updateProfile(profile)
    }

    func signOut() async {
        try? await backend.signOut()
    }

    func deleteAccount() async {
        guard let userId = session?.userId else { return }
        try? await backend.deleteAccount(userId: userId)
    }

    func updateNotificationSettings(_ mutate: (inout NotificationSettings) -> Void) {
        mutate(&notificationSettings)
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        Task { try? await backend.updateNotificationSettings(notificationSettings, userId: requireUserId()) }
    }

    // MARK: - Helpers

    /// Keeps perHabitReminders in lockstep with the habits list: new habits get a row,
    /// deleted habits lose theirs. Needed once at bootstrap since fetched settings and
    /// fetched habits come from independent queries that can drift.
    private func reconcilePerHabitReminders() {
        let habitIds = Set(habits.map(\.id))
        notificationSettings.perHabitReminders.removeAll { !habitIds.contains($0.habitId) }
        let existingIds = Set(notificationSettings.perHabitReminders.map(\.habitId))
        for habit in habits where !existingIds.contains(habit.id) {
            notificationSettings.perHabitReminders.append(
                HabitReminder(habitId: habit.id, habitName: habit.name, time: DateComponents(hour: 7, minute: 0), isOn: true)
            )
        }
    }

    private func requireUserId() -> UUID {
        session?.userId ?? MockBackendService.demoUserId
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled { toast = nil }
        }
    }
}
