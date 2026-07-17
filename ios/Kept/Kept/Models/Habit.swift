import Foundation

enum HabitVisibility: String, Codable, CaseIterable, Identifiable, Hashable {
    case open
    case kept

    var id: String { rawValue }

    var pickerDescription: String {
        switch self {
        case .open: return "Shows up in Circle. Friends can nudge and react."
        case .kept: return "Just for you. Invisible to everyone."
        }
    }
}

/// One of a set of preset goal lengths, or a custom day count, or none (ongoing).
enum HabitDuration: Equatable, Hashable {
    case ongoing
    case days(Int)

    var totalDays: Int? {
        switch self {
        case .ongoing: return nil
        case .days(let n): return n
        }
    }

    static let presets: [HabitDuration] = [.ongoing, .days(7), .days(21), .days(30), .days(90)]

    var isPreset: Bool { HabitDuration.presets.contains(self) }

    var note: String {
        switch self {
        case .ongoing:
            return "This habit stays on your list indefinitely. No end date."
        case .days(let n):
            return "This habit wraps up after \(n) days, then we'll ask if you want to keep going."
        }
    }
}

struct Habit: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var visibility: HabitVisibility
    var createdAt: Date
    var goalDurationDays: Int?
    /// Logical check-in days (already normalized via DayCalendar), ascending, unique.
    var checkInHistory: [Date]
    /// Kept+ only: when non-empty and visibility is .open, restricts who in your Circle
    /// can actually see this habit's check-ins to just these member ids, instead of
    /// everyone — e.g. sharing an accountability habit with just Bobby instead of your
    /// whole Circle. Empty means the normal "everyone in Circle" behavior. Still
    /// fundamentally "Open," not a third visibility state — no new color, no new meaning.
    var sharedWithMemberIds: Set<UUID>

    init(
        id: UUID = UUID(),
        name: String,
        visibility: HabitVisibility,
        createdAt: Date = Date(),
        goalDurationDays: Int? = nil,
        checkInHistory: [Date] = [],
        sharedWithMemberIds: Set<UUID> = []
    ) {
        self.id = id
        self.name = name
        self.visibility = visibility
        self.createdAt = createdAt
        self.goalDurationDays = goalDurationDays
        self.checkInHistory = checkInHistory
        self.sharedWithMemberIds = sharedWithMemberIds
    }

    var hasCustomAudience: Bool { !sharedWithMemberIds.isEmpty }

    var duration: HabitDuration {
        get { goalDurationDays.map(HabitDuration.days) ?? .ongoing }
        set { goalDurationDays = newValue.totalDays }
    }

    func daysSinceStart(now: Date = Date(), calendar: DayCalendar = DayCalendar()) -> Int {
        max(1, calendar.daysBetween(createdAt, now) + 1)
    }

    func isCheckedIn(on date: Date = Date(), calendar: DayCalendar = DayCalendar()) -> Bool {
        let target = calendar.logicalDay(for: date)
        return checkInHistory.contains { calendar.logicalDay(for: $0) == target }
    }

    /// Consecutive logical days checked in, counting back from today (or yesterday, if
    /// today hasn't been checked in yet, so the streak doesn't visually zero out mid-day).
    func streakCount(now: Date = Date(), calendar: DayCalendar = DayCalendar()) -> Int {
        calendar.consecutiveStreak(through: checkInHistory, now: now)
    }

    /// The longest run of consecutive days anywhere in this habit's history, not just the
    /// one ending today — for Streak Insights, where "your best 21-day run in March" is
    /// the interesting number, not just the current live streak.
    func longestStreak(calendar: DayCalendar = DayCalendar()) -> Int {
        let days = Set(checkInHistory.map { calendar.logicalDay(for: $0) }).sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<days.count {
            let gap = Calendar.current.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 0
            current = gap == 1 ? current + 1 : 1
            longest = max(longest, current)
        }
        return longest
    }

    /// Subtitle line: only present when there's something to say, never restates Open/Kept.
    func subtitle(now: Date = Date(), calendar: DayCalendar = DayCalendar()) -> String? {
        var parts: [String] = []
        if isCheckedIn(on: now, calendar: calendar) {
            parts.append("checked in today")
        }
        if let goal = goalDurationDays {
            parts.append("Day \(min(daysSinceStart(now: now, calendar: calendar), goal)) of \(goal)")
        }
        if hasCustomAudience {
            parts.append("shared with \(sharedWithMemberIds.count)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    mutating func checkIn(on date: Date = Date(), calendar: DayCalendar = DayCalendar()) {
        guard !isCheckedIn(on: date, calendar: calendar) else { return }
        checkInHistory.append(calendar.logicalDay(for: date))
        checkInHistory.sort()
    }

    mutating func undoCheckIn(on date: Date = Date(), calendar: DayCalendar = DayCalendar()) {
        let target = calendar.logicalDay(for: date)
        checkInHistory.removeAll { calendar.logicalDay(for: $0) == target }
    }
}
