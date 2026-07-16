import Foundation

struct HabitReminder: Identifiable, Codable, Equatable {
    var habitId: UUID
    var habitName: String
    var time: DateComponents
    var isOn: Bool

    var id: UUID { habitId }
}

struct NotificationSettings: Codable, Equatable {
    var remindForAllHabits: Bool = true
    var allHabitsTime: DateComponents = DateComponents(hour: 7, minute: 0)
    var customizePerHabit: Bool = false
    var perHabitReminders: [HabitReminder] = []
    /// When the logical day rolls over and streaks/check-ins reset. Default midnight.
    var dayResetHour: Int = 0

    var dayCalendar: DayCalendar { DayCalendar(resetHour: dayResetHour) }
}
