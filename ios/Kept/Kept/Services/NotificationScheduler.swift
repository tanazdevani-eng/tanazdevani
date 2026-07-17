import Foundation
import UserNotifications
import UIKit

/// Schedules local reminder notifications. The Notifications screen is just a view over
/// NotificationSettings; this is what actually turns those settings into
/// UNNotificationRequests — the mockup's version of this screen was UI-only.
final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    private let globalIdentifier = "kept.reminder.global"

    /// Requests permission the first time, and re-registers for a remote (APNs) device
    /// token on every call once permission exists — tokens can rotate, so this needs to
    /// run again each launch, not just on the very first grant. Safe to call often:
    /// registerForRemoteNotifications() is a no-op if already registered.
    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            default:
                break
            }
        }
    }

    /// Clears every reminder Kept owns and reschedules from scratch based on current
    /// settings. Simpler and less error-prone than diffing, and cheap since this only
    /// runs on explicit user changes (toggling a switch, adding/renaming/deleting a habit).
    func syncReminders(for habits: [Habit], settings: NotificationSettings) {
        center.getPendingNotificationRequests { requests in
            let keptIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("kept.reminder.") }
            self.center.removePendingNotificationRequests(withIdentifiers: keptIdentifiers)

            if settings.customizePerHabit {
                for reminder in settings.perHabitReminders where reminder.isOn {
                    self.schedule(
                        identifier: self.identifier(for: reminder.habitId),
                        title: reminder.habitName,
                        body: "Have you kept it today?",
                        time: reminder.time
                    )
                }
            } else if settings.remindForAllHabits {
                self.schedule(
                    identifier: self.globalIdentifier,
                    title: "Kept",
                    body: "A quick check-in for everything on your list.",
                    time: settings.allHabitsTime
                )
            }
        }
    }

    private func identifier(for habitId: UUID) -> String {
        "kept.reminder.habit.\(habitId.uuidString)"
    }

    private func schedule(identifier: String, title: String, body: String, time: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var trigger = DateComponents()
        trigger.hour = time.hour
        trigger.minute = time.minute
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        center.add(request)
    }
}
