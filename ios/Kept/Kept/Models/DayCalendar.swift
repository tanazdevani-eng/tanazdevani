import Foundation

/// Resolves "what calendar day is this" against the user's day-reset time (Notifications
/// screen, default midnight) instead of always using midnight, so a 1am check-in after a
/// 2am reset still counts as "yesterday."
struct DayCalendar {
    var resetHour: Int = 0

    func logicalDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let shifted = calendar.date(byAdding: .hour, value: -resetHour, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = logicalDay(for: start)
        let endDay = logicalDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }

    /// Longest run of consecutive logical days in `dates` ending today or yesterday (so a
    /// streak doesn't visually zero out before the day's actual cutoff has passed). Shared
    /// by both a single habit's streak and the app-wide "any check-in" streak so the two
    /// can never drift out of sync with each other.
    func consecutiveStreak(through dates: some Sequence<Date>, now: Date = Date()) -> Int {
        let checkedDays = Set(dates.map { logicalDay(for: $0) })
        guard !checkedDays.isEmpty else { return 0 }

        var cursor = logicalDay(for: now)
        if !checkedDays.contains(cursor) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
            guard checkedDays.contains(cursor) else { return 0 }
        }

        var streak = 0
        while checkedDays.contains(cursor) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
