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
}
