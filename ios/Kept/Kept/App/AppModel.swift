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
    @Published var selectedTab: RootTab = .circle
    /// Kept+ isn't a tab — this presents it as a sheet from wherever an upsell fires
    /// (Add Habit's 3-habit cap, Streak Insights' locked state, Profile's upgrade box).
    @Published var showingPaywall = false

    /// Drives which top-level screen AuthGateView shows: a launch spinner while checking
    /// for an existing session, the phone sign-up/log-in flow, the one-time post-signup
    /// profile step, or the real app.
    @Published private(set) var authStage: AuthStage = .checkingSession
    enum AuthStage: Equatable { case checkingSession, needsAuth, needsOnboarding, authenticated }

    /// Demo seed for friends' Circle activity until real multi-user Supabase data is
    /// wired up (fetchCircleFeed returns [] against a fresh project with only you in it).
    @Published var friendFeedItems: [CircleFeedItem]
    /// Today's optional check-in note per habit, shown on the Circle card until undone.
    @Published var todaysNotes: [UUID: String] = [:]
    /// Comments on your own today's check-ins, keyed by habit id (mirrors todaysNotes,
    /// since "mine" Circle feed items are derived rather than stored — see circleFeed).
    @Published var todaysComments: [UUID: [Comment]] = [:]
    /// Habits logged today as a "down day" (couldn't get to it) instead of checked in —
    /// a real post, not silence, but never in checkInHistory so it never extends a streak.
    /// Mutually exclusive with being checked in today; the note lives in todaysNotes same
    /// as a normal check-in's note does.
    @Published var downDayHabitIds: Set<UUID> = []
    /// Friends nudged this session, so the button can flip to a disabled "Nudged" state.
    @Published var nudgedAuthorIds: Set<UUID> = []
    /// Set by handleIncomingURL when someone taps a kept://invite link. RootTabView shows
    /// the Accept/Decline sheet for this the moment it's non-nil (which naturally only
    /// happens once the recipient is authenticated, since that's the only place it's read).
    @Published var incomingInvite: IncomingInvite?

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
    /// App-wide streak: consecutive days you checked in on *anything*, not your single best
    /// habit's streak — one habit slipping shouldn't erase the rest of your consistency,
    /// and it keeps this number from ever contradicting what the cards below it show.
    var overallStreak: Int { dayCalendar.consecutiveStreak(through: habits.flatMap(\.checkInHistory)) }

    init(backend: BackendService, storeKit: StoreKitManager, scheduler: NotificationScheduler = NotificationScheduler()) {
        self.backend = backend
        self.storeKit = storeKit
        self.scheduler = scheduler
        self.profile = UserProfile(name: "", handle: "", bio: "")
        self.friendFeedItems = Self.demoFriendFeed()
    }

    /// Starts empty, same as a real account would (fetchCircleFeed returns [] until real
    /// multi-user Circle syncing is wired up) — so testing against the mock backend shows
    /// the same thing a brand-new install actually shows, not fake Bobby/Gigi activity
    /// that no real new user would ever see. Also what sign-out/delete resets back to.
    private static func demoFriendFeed() -> [CircleFeedItem] { [] }

    // MARK: - Auth

    /// Runs once at launch: is there already a signed-in session (a returning user who
    /// never logged out)? If so, skip straight past the Welcome screen into their data.
    func checkExistingSession() async {
        do {
            if let existing = try await backend.currentSession() {
                session = existing
                try await loadUserData(userId: existing.userId)
                authStage = .authenticated
            } else {
                authStage = .needsAuth
            }
        } catch {
            authStage = .needsAuth
        }
    }

    func requestVerificationCode(phone: String) async throws {
        try await backend.requestOTP(phone: phone)
    }

    /// Signing up and logging in both end at the same OTP verification — phone auth
    /// auto-creates the account server-side either way — so `intent` (which button was
    /// tapped on Welcome) is what actually decides whether this lands in the one-time
    /// onboarding step or straight into existing data.
    func verifyCode(phone: String, code: String, intent: AuthIntent) async throws {
        let newSession = try await backend.verifyOTP(phone: phone, code: code)
        session = newSession

        if intent == .signUp {
            profile = UserProfile(id: newSession.userId, name: "", handle: "", bio: "")
            habits = []
            circleMembers = []
            pendingInvites = []
            contacts = (try? await backend.fetchContacts(userId: newSession.userId)) ?? []
            notificationSettings = NotificationSettings()
            authStage = .needsOnboarding
        } else {
            try await loadUserData(userId: newSession.userId)
            authStage = .authenticated
        }
    }

    /// The one-time step after a fresh sign-up: just name + username, matching Hinge's
    /// approach of "onboarding is profile setup," not a separate tutorial. Notification
    /// permission (with a "why we want this" screen first) is the step after this one.
    func completeProfileOnboarding(name: String, handle: String) {
        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.handle = handle.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        performBackendSync { [self] in try await self.backend.updateProfile(self.profile) }
    }

    func requestNotificationPermission() {
        scheduler.requestAuthorizationIfNeeded()
    }

    /// Called by KeptAppDelegate once APNs hands back a device token. Silent no-op failure
    /// on purpose — a push token that didn't save shouldn't surface as an error toast to
    /// someone who's just using the app normally.
    func registerPushToken(_ token: String) async {
        guard let userId = session?.userId else { return }
        try? await backend.registerPushToken(userId: userId, token: token)
    }

    func finishOnboarding() {
        authStage = .authenticated
        showToast("Welcome to Kept")
    }

    func signOut() async {
        try? await backend.signOut()
        resetLocalState()
        authStage = .needsAuth
    }

    func deleteAccount() async {
        guard let userId = session?.userId else { return }
        try? await backend.deleteAccount(userId: userId)
        resetLocalState()
        authStage = .needsAuth
    }

    private func loadUserData(userId: UUID) async throws {
        async let profileFetch = backend.fetchProfile(userId: userId)
        async let habitsFetch = backend.fetchHabits(userId: userId)
        async let membersFetch = backend.fetchCircleMembers(userId: userId)
        async let invitesFetch = backend.fetchPendingInvites(userId: userId)
        async let contactsFetch = backend.fetchContacts(userId: userId)
        async let settingsFetch = backend.fetchNotificationSettings(userId: userId)

        profile = try await profileFetch
        habits = try await habitsFetch
        circleMembers = try await membersFetch
        pendingInvites = try await invitesFetch
        contacts = try await contactsFetch
        notificationSettings = try await settingsFetch
        reconcilePerHabitReminders()
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        // Re-registers for a remote device token if permission was already granted in an
        // earlier session — tokens can rotate, so this needs a chance to run every launch,
        // not just the first time someone taps "Enable notifications" in onboarding.
        scheduler.requestAuthorizationIfNeeded()
    }

    private func resetLocalState() {
        session = nil
        profile = UserProfile(name: "", handle: "", bio: "")
        habits = []
        circleMembers = []
        pendingInvites = []
        contacts = []
        notificationSettings = NotificationSettings()
        defaultVisibility = .open
        todaysNotes = [:]
        todaysComments = [:]
        downDayHabitIds = []
        nudgedAuthorIds = []
        friendFeedItems = Self.demoFriendFeed()
        selectedTab = .circle
    }

    /// Pull-to-refresh: re-fetches everything that can change from outside this device
    /// (a friend's new post, a reaction, someone accepting an invite) without the launch
    /// screen or disturbing local state that's mid-edit.
    func refresh() async {
        guard let userId = session?.userId else { return }
        do {
            async let habitsFetch = backend.fetchHabits(userId: userId)
            async let membersFetch = backend.fetchCircleMembers(userId: userId)
            async let invitesFetch = backend.fetchPendingInvites(userId: userId)
            async let feedFetch = backend.fetchCircleFeed(userId: userId)

            habits = try await habitsFetch
            circleMembers = try await membersFetch
            pendingInvites = try await invitesFetch
            let freshFriendFeed = try await feedFetch
            if !freshFriendFeed.isEmpty {
                friendFeedItems = freshFriendFeed
            }
            reconcilePerHabitReminders()
        } catch {
            showToast("Couldn't refresh. Check your connection")
        }
    }

    // MARK: - Habits

    @discardableResult
    func addHabit(name: String, visibility: HabitVisibility, duration: HabitDuration, sharedWithMemberIds: Set<UUID> = []) -> Bool {
        guard canAddHabit else { return false }
        let habit = Habit(
            name: name, visibility: visibility, goalDurationDays: duration.totalDays,
            sharedWithMemberIds: visibility == .open ? sharedWithMemberIds : []
        )
        habits.append(habit)
        notificationSettings.perHabitReminders.append(
            HabitReminder(habitId: habit.id, habitName: name, time: DateComponents(hour: 7, minute: 0), isOn: true)
        )
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        performBackendSync { [self] in try await backend.createHabit(habit, userId: requireUserId()) }
        showToast("\"\(name)\" added")
        return true
    }

    func updateHabit(_ habit: Habit, name: String, visibility: HabitVisibility, duration: HabitDuration, sharedWithMemberIds: Set<UUID>) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].name = name
        habits[index].visibility = visibility
        habits[index].duration = duration
        habits[index].sharedWithMemberIds = visibility == .open ? sharedWithMemberIds : []
        if visibility == .kept {
            todaysNotes.removeValue(forKey: habit.id)
        }
        if let reminderIndex = notificationSettings.perHabitReminders.firstIndex(where: { $0.habitId == habit.id }) {
            notificationSettings.perHabitReminders[reminderIndex].habitName = name
        }
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        performBackendSync { [self] in try await backend.updateHabit(habits[index]) }
        showToast("Habit updated")
    }

    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        todaysNotes.removeValue(forKey: habit.id)
        notificationSettings.perHabitReminders.removeAll { $0.habitId == habit.id }
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        performBackendSync { [self] in try await backend.deleteHabit(id: habit.id) }
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
        if becameKept {
            habits[index].sharedWithMemberIds = []
        }
        if becameKept && habits[index].isCheckedIn(calendar: dayCalendar) {
            showToast("Made private. Pulled from Circle too")
        }
        performBackendSync { [self] in try await backend.updateHabit(habits[index]) }
    }

    /// Set right when a fixed-duration habit's final day gets checked in, so the UI can
    /// ask "keep going or let it end" — only fires once, since checking in again the same
    /// day isn't possible (the button becomes an undo toggle instead).
    @Published var goalCompletedHabit: Habit?

    func checkIn(_ habit: Habit, note: String?) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].checkIn(calendar: dayCalendar)
        downDayHabitIds.remove(habit.id)
        if let note, !note.isEmpty {
            todaysNotes[habit.id] = note
        }
        let day = dayCalendar.logicalDay(for: Date())
        performBackendSync { [self] in try await backend.setCheckIn(habitId: habit.id, userId: requireUserId(), day: day, note: note, checkedIn: true, status: "done") }

        if let goal = habits[index].goalDurationDays, habits[index].daysSinceStart(calendar: dayCalendar) >= goal {
            goalCompletedHabit = habits[index]
        }
    }

    /// "Down day" — logged on purpose (couldn't get to it today), a real Circle post like
    /// any check-in, but never appended to checkInHistory so it never extends a streak.
    /// Mutually exclusive with checkIn(_:note:); calling this on an already-checked-in
    /// habit un-checks it first, since a day can't be both.
    func logDownDay(_ habit: Habit, note: String?) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].undoCheckIn(calendar: dayCalendar)
        downDayHabitIds.insert(habit.id)
        if let note, !note.isEmpty {
            todaysNotes[habit.id] = note
        } else {
            todaysNotes.removeValue(forKey: habit.id)
        }
        let day = dayCalendar.logicalDay(for: Date())
        performBackendSync { [self] in try await backend.setCheckIn(habitId: habit.id, userId: requireUserId(), day: day, note: note, checkedIn: true, status: "missed") }
    }

    /// Pulls back a down-day post, same idea as undoCheckIn but for the "missed" branch —
    /// used by the "✕" on your own down-day card in Circle.
    func undoDownDay(_ habit: Habit) {
        downDayHabitIds.remove(habit.id)
        todaysNotes.removeValue(forKey: habit.id)
        todaysComments.removeValue(forKey: habit.id)
        let day = dayCalendar.logicalDay(for: Date())
        performBackendSync { [self] in try await backend.setCheckIn(habitId: habit.id, userId: requireUserId(), day: day, note: nil, checkedIn: false, status: "missed") }
        showToast("Down day removed")
    }

    /// Fixes or clears the note on today's check-in without undoing the check-in itself —
    /// the two are separate concerns (todaysNotes vs. checkInHistory), so this only ever
    /// touches the note. `note: nil` (or empty) removes it entirely.
    func updateNote(for habit: Habit, note: String?) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            todaysNotes[habit.id] = trimmed
        } else {
            todaysNotes.removeValue(forKey: habit.id)
        }
        let day = dayCalendar.logicalDay(for: Date())
        let status = downDayHabitIds.contains(habit.id) ? "missed" : "done"
        performBackendSync { [self] in
            try await backend.setCheckIn(habitId: habit.id, userId: requireUserId(), day: day, note: trimmed, checkedIn: true, status: status)
        }
    }

    /// "Keep going" from the goal-complete prompt: removes the day cap so the habit keeps
    /// appearing on Home indefinitely, same streak and history intact.
    func keepHabitGoing(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].goalDurationDays = nil
        performBackendSync { [self] in try await backend.updateHabit(habits[index]) }
        showToast("Keeping \"\(habit.name)\" going")
        goalCompletedHabit = nil
    }

    /// "I'm done" from the goal-complete prompt: the goal was the point, so this actually
    /// removes the habit rather than just quietly leaving it on the list with nothing left
    /// to do — the intent was already confirmed by choosing this over "Keep going."
    func finishHabitGoal(_ habit: Habit) {
        deleteHabit(habit)
        goalCompletedHabit = nil
    }

    func undoCheckIn(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[index].undoCheckIn(calendar: dayCalendar)
        todaysNotes.removeValue(forKey: habit.id)
        todaysComments.removeValue(forKey: habit.id)
        let day = dayCalendar.logicalDay(for: Date())
        performBackendSync { [self] in try await backend.setCheckIn(habitId: habit.id, userId: requireUserId(), day: day, note: nil, checkedIn: false, status: "done") }
        showToast("Check-in undone")
    }

    // MARK: - Circle feed (derived)

    var circleFeed: [CircleFeedItem] {
        let mine: [CircleFeedItem] = habits
            .filter { $0.visibility == .open && ($0.isCheckedIn(calendar: dayCalendar) || downDayHabitIds.contains($0.id)) }
            .map { habit in
                let isDownDay = downDayHabitIds.contains(habit.id)
                return CircleFeedItem(
                    id: habit.id,
                    authorId: profile.id,
                    authorName: "You",
                    avatarSeed: 0,
                    isMine: true,
                    habitId: habit.id,
                    habitName: habit.name,
                    note: todaysNotes[habit.id],
                    timeLabel: "just now",
                    streakCount: habit.streakCount(calendar: dayCalendar),
                    goalDurationDays: habit.goalDurationDays,
                    dayNumber: habit.goalDurationDays.map { min(habit.daysSinceStart(calendar: dayCalendar), $0) },
                    status: isDownDay ? .missed : .done,
                    hasCheckedInToday: !isDownDay,
                    reactions: [],
                    myReactionEmoji: nil,
                    comments: todaysComments[habit.id] ?? []
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
        performBackendSync { [self] in try await backend.sendReaction(feedItemId: item.id, userId: requireUserId(), emoji: emoji) }
    }

    /// Nudge is only ever offered on people who haven't checked in today — the caller
    /// (CircleView) already filters for that, this just fires the request. Tracks who's
    /// already been nudged today so the button can flip to a disabled "Nudged" state
    /// instead of silently allowing repeat taps with no feedback that it registered.
    func nudge(_ item: CircleFeedItem) {
        nudgedAuthorIds.insert(item.authorId)
        showToast("You nudged \(item.authorName)")
        performBackendSync { [self] in try await backend.sendNudge(userId: requireUserId(), memberId: item.authorId, day: dayCalendar.logicalDay(for: Date())) }
    }

    /// Works for both a friend's post (stored on friendFeedItems) and your own (stored in
    /// todaysComments, keyed by habit id, since "mine" feed items are derived rather than
    /// stored — see circleFeed above).
    func addComment(to item: CircleFeedItem, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = Comment(id: UUID(), authorName: "You", text: trimmed, postedAt: Date())

        if item.isMine, let habitId = item.habitId {
            todaysComments[habitId, default: []].append(comment)
        } else if let index = friendFeedItems.firstIndex(where: { $0.id == item.id }) {
            friendFeedItems[index].comments.append(comment)
        } else {
            return
        }
        performBackendSync { [self] in try await backend.addComment(feedItemId: item.id, userId: requireUserId(), text: trimmed) }
    }

    /// Guideline 1.2 (UGC): lets someone flag a Circle post for review. Pulls it from the
    /// local feed immediately so the reporter doesn't keep seeing what they just reported,
    /// even though the real moderation decision happens on our end afterward.
    func reportPost(_ item: CircleFeedItem, reason: String) {
        friendFeedItems.removeAll { $0.id == item.id }
        showToast("Reported. Thanks for flagging it.")
        performBackendSync { [self] in
            try await backend.reportCheckIn(checkInId: item.id, reporterId: requireUserId(), reportedUserId: item.authorId, reason: reason)
        }
    }

    /// Blocking hides everything from that person going forward — the
    /// check_ins_circle_select_open_today RLS policy already excludes a blocker's posts
    /// from a blocked user's feed server-side, this just prunes today's already-fetched
    /// items locally for instant feedback.
    func blockUser(_ item: CircleFeedItem) {
        let authorId = item.authorId
        let authorName = item.authorName
        friendFeedItems.removeAll { $0.authorId == authorId }
        showToast("\(authorName) blocked")
        performBackendSync { [self] in try await backend.blockUser(blockerId: requireUserId(), blockedId: authorId) }
    }

    // MARK: - Circle management

    func removeMember(_ member: CircleMember) {
        circleMembers.removeAll { $0.id == member.id }
        showToast("\(member.name) removed")
        performBackendSync { [self] in try await backend.removeMember(id: member.id) }
    }

    func cancelInvite(_ invite: PendingInvite) {
        pendingInvites.removeAll { $0.id == invite.id }
        showToast("Invite canceled")
        performBackendSync { [self] in try await backend.cancelInvite(id: invite.id) }
    }

    func sendInvite(to contact: Contact) {
        contacts.removeAll { $0.id == contact.id }
        pendingInvites.append(PendingInvite(id: contact.id, name: contact.name, avatarSeed: contact.avatarSeed, invitedAt: Date()))
        performBackendSync { [self] in try await backend.sendInvite(userId: requireUserId(), contact: contact) }
    }

    // MARK: - Invite links (accept side)

    /// A real, taggable deep link — opens the app directly to an Accept/Decline screen for
    /// whoever taps it (see handleIncomingURL below). Custom URL scheme, not a Universal
    /// Link: works the moment the recipient has Kept installed, but — unlike an https link
    /// — can't fall back to the App Store if they don't have it yet. That fallback needs a
    /// real hosted domain with an apple-app-site-association file, which is a step for
    /// later once there's a website to host it on.
    var inviteShareURL: URL {
        var components = URLComponents()
        components.scheme = "kept"
        components.host = "invite"
        components.queryItems = [
            URLQueryItem(name: "inviter", value: profile.id.uuidString),
            URLQueryItem(name: "name", value: profile.name.isEmpty ? "A friend" : profile.name),
        ]
        return components.url!
    }

    /// Deliberately doesn't include the raw URL as visible text — ShareLink already
    /// attaches inviteShareURL separately and shows its own link preview, so folding the
    /// (ugly, UUID-and-query-string-bearing) URL into this string would just show up
    /// twice, once as a rich preview and once as raw text.
    var inviteShareMessage: String {
        "I'm using Kept to stay on track with my habits. Join my circle on Kept."
    }

    /// Parses a tapped kept://invite link. Setting incomingInvite here is safe to call
    /// before the recipient is signed in — RootTabView (where the accept sheet lives)
    /// only exists once authStage is .authenticated, so the sheet naturally waits until
    /// after they've signed up or logged in and simply appears once it does.
    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "kept", url.host == "invite" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let inviterIdString = items.first(where: { $0.name == "inviter" })?.value,
              let inviterId = UUID(uuidString: inviterIdString),
              inviterId != profile.id else { return }
        let inviterName = items.first(where: { $0.name == "name" })?.value ?? "A friend"
        incomingInvite = IncomingInvite(inviterId: inviterId, inviterName: inviterName)
    }

    /// Mutual: both people end up able to see each other's Open habits, matching how
    /// Circle already works elsewhere (removing/blocking someone is one-directional, but
    /// joining a circle together is the whole point of accepting an invite).
    func acceptIncomingInvite() {
        guard let invite = incomingInvite else { return }
        incomingInvite = nil
        if !circleMembers.contains(where: { $0.id == invite.inviterId }) {
            circleMembers.append(CircleMember(id: invite.inviterId, name: invite.inviterName, avatarSeed: abs(invite.inviterName.hashValue) % 6, openHabitCount: 0))
        }
        showToast("You're circled with \(invite.inviterName)")
        let accepterName = profile.name.isEmpty ? "Someone" : profile.name
        performBackendSync { [self] in
            try await backend.acceptInvite(inviterId: invite.inviterId, accepterId: requireUserId())
            // Best-effort: a push that doesn't land shouldn't surface as a "couldn't save"
            // toast for what is, from the accepter's side, a fully successful action.
            try? await backend.notifyInviteAccepted(inviterId: invite.inviterId, accepterName: accepterName)
        }
    }

    func declineIncomingInvite() {
        incomingInvite = nil
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
        performBackendSync { [self] in try await backend.updateProfile(profile) }
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

    func updateNotificationSettings(_ mutate: (inout NotificationSettings) -> Void) {
        mutate(&notificationSettings)
        scheduler.syncReminders(for: habits, settings: notificationSettings)
        performBackendSync { [self] in try await backend.updateNotificationSettings(notificationSettings, userId: requireUserId()) }
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

    /// Local state always updates optimistically first (the UI should never wait on a
    /// network round trip to feel responsive); this is what actually ships that change to
    /// the backend, and — unlike a bare `try? await backend.x()` — surfaces a toast if it
    /// fails instead of silently pretending everything saved when it didn't.
    private func performBackendSync(_ operation: @escaping () async throws -> Void) {
        Task {
            do {
                try await operation()
            } catch {
                showToast("Couldn't save. Check your connection")
            }
        }
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
