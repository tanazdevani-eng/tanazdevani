import SwiftUI

struct NotificationsSettingsView: View {
    @EnvironmentObject var appModel: AppModel

    private let timeOptions: [DateComponents] = [
        DateComponents(hour: 6, minute: 0), DateComponents(hour: 7, minute: 0), DateComponents(hour: 8, minute: 0),
        DateComponents(hour: 9, minute: 0), DateComponents(hour: 12, minute: 0), DateComponents(hour: 18, minute: 0),
        DateComponents(hour: 20, minute: 0), DateComponents(hour: 21, minute: 0),
    ]
    private let resetOptions: [Int] = [0, 2, 3, 5]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionLabel("Reminders").padding(.top, 4)
                VStack(spacing: 0) {
                    row(title: "Remind me for all habits", subtitle: "One nudge a day covering everything") {
                        Toggle("", isOn: Binding(
                            get: { appModel.notificationSettings.remindForAllHabits },
                            set: { newValue in appModel.updateNotificationSettings { $0.remindForAllHabits = newValue } }
                        )).labelsHidden()
                    }
                    if appModel.notificationSettings.remindForAllHabits {
                        row(title: "Reminder time", subtitle: "Applies to every habit unless customized below") {
                            timeChip(components(appModel.notificationSettings.allHabitsTime)) {
                                appModel.updateNotificationSettings { $0.allHabitsTime = nextTime($0.allHabitsTime) }
                            }
                        }
                    }
                    row(title: "Customize per habit", subtitle: "Different times for different habits") {
                        Toggle("", isOn: Binding(
                            get: { appModel.notificationSettings.customizePerHabit },
                            set: { newValue in appModel.updateNotificationSettings { $0.customizePerHabit = newValue } }
                        )).labelsHidden()
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))

                Text("When \u{201C}Customize per habit\u{201D} is on, each habit gets its own reminder and time instead of the shared one above.")
                    .font(KeptFont.body(11.5, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .padding(.top, 16)

                if appModel.notificationSettings.customizePerHabit {
                    VStack(spacing: 0) {
                        ForEach(appModel.notificationSettings.perHabitReminders) { reminder in
                            perHabitRow(reminder)
                        }
                    }
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))
                    .padding(.top, 10)
                }

                sectionLabel("Day reset").padding(.top, 20)
                VStack(spacing: 0) {
                    row(title: "New day starts at", subtitle: "When streaks roll over and today's check-ins reset") {
                        timeChip(DateComponents(hour: appModel.notificationSettings.dayResetHour, minute: 0)) {
                            appModel.updateNotificationSettings { $0.dayResetHour = nextResetHour($0.dayResetHour) }
                        }
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))

                Text("Night owl or shift worker? Push this later so a late check-in still counts as \u{201C}today.\u{201D}")
                    .font(KeptFont.body(11.5, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .padding(.top, 12)
            }
            .padding(22)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func perHabitRow(_ reminder: HabitReminder) -> some View {
        HStack(spacing: 10) {
            Text(reminder.habitName).font(KeptFont.body(13, weight: .semibold)).foregroundStyle(.keptInk)
            Spacer()
            timeChip(reminder.time) {
                appModel.updateNotificationSettings { settings in
                    guard let i = settings.perHabitReminders.firstIndex(where: { $0.habitId == reminder.habitId }) else { return }
                    settings.perHabitReminders[i].time = nextTime(settings.perHabitReminders[i].time)
                }
            }
            Toggle("", isOn: Binding(
                get: { reminder.isOn },
                set: { newValue in
                    appModel.updateNotificationSettings { settings in
                        guard let i = settings.perHabitReminders.firstIndex(where: { $0.habitId == reminder.habitId }) else { return }
                        settings.perHabitReminders[i].isOn = newValue
                    }
                }
            )).labelsHidden()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 16) }
    }

    private func row(title: String, subtitle: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(KeptFont.body(13.5, weight: .bold)).foregroundStyle(.keptInk)
                Text(subtitle).font(KeptFont.body(11, weight: .medium)).foregroundStyle(.keptInkSoft)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 16) }
    }

    private func timeChip(_ components: DateComponents, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(formatted(components))
                .font(KeptFont.mono(11.5, weight: .semibold))
                .foregroundStyle(.keptInk)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.keptBackground)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(.keptLine))
        }
    }

    private func components(_ dc: DateComponents) -> DateComponents { dc }

    private func formatted(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let period = hour < 12 ? "AM" : "PM"
        var displayHour = hour % 12
        if displayHour == 0 { displayHour = 12 }
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private func nextTime(_ current: DateComponents) -> DateComponents {
        guard let index = timeOptions.firstIndex(where: { $0.hour == current.hour && $0.minute == current.minute }) else {
            return timeOptions[0]
        }
        return timeOptions[(index + 1) % timeOptions.count]
    }

    private func nextResetHour(_ current: Int) -> Int {
        guard let index = resetOptions.firstIndex(of: current) else { return resetOptions[0] }
        return resetOptions[(index + 1) % resetOptions.count]
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(KeptFont.mono(10.5, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}
