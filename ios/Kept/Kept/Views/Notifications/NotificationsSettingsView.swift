import SwiftUI

struct NotificationsSettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var editingTarget: TimeEditTarget?

    private struct TimeEditTarget: Identifiable {
        let id: String
        let title: String
        let components: DateComponents
        let showsMinute: Bool
        let onSave: (DateComponents) -> Void
    }

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
                            timeChip(appModel.notificationSettings.allHabitsTime) {
                                editingTarget = TimeEditTarget(
                                    id: "allHabits",
                                    title: "Reminder time",
                                    components: appModel.notificationSettings.allHabitsTime,
                                    showsMinute: true,
                                    onSave: { newTime in appModel.updateNotificationSettings { $0.allHabitsTime = newTime } }
                                )
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
                .background(.keptSurface)
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
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))
                    .padding(.top, 10)
                }

                sectionLabel("Day reset").padding(.top, 20)
                VStack(spacing: 0) {
                    row(title: "New day starts at", subtitle: "When streaks roll over and today's check-ins reset") {
                        timeChip(DateComponents(hour: appModel.notificationSettings.dayResetHour, minute: 0)) {
                            editingTarget = TimeEditTarget(
                                id: "dayReset",
                                title: "New day starts at",
                                components: DateComponents(hour: appModel.notificationSettings.dayResetHour, minute: 0),
                                showsMinute: false,
                                onSave: { newTime in appModel.updateNotificationSettings { $0.dayResetHour = newTime.hour ?? 0 } }
                            )
                        }
                    }
                }
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.keptLine))

                Text("Night owl or shift worker? Push this later so a late check-in still counts as \u{201C}today.\u{201D}")
                    .font(KeptFont.body(11.5, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .padding(.top, 12)
            }
            .padding(22)
            .padding(.bottom, 90)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTarget) { target in
            TimeEditSheet(title: target.title, initialComponents: target.components, showsMinute: target.showsMinute, onSave: target.onSave)
        }
    }

    private func perHabitRow(_ reminder: HabitReminder) -> some View {
        HStack(spacing: 10) {
            Text(reminder.habitName).font(KeptFont.body(13, weight: .semibold)).foregroundStyle(.keptInk)
            Spacer()
            timeChip(reminder.time) {
                editingTarget = TimeEditTarget(
                    id: "habit-\(reminder.habitId)",
                    title: reminder.habitName,
                    components: reminder.time,
                    showsMinute: true,
                    onSave: { newTime in
                        appModel.updateNotificationSettings { settings in
                            guard let i = settings.perHabitReminders.firstIndex(where: { $0.habitId == reminder.habitId }) else { return }
                            settings.perHabitReminders[i].time = newTime
                        }
                    }
                )
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

    private func formatted(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let period = hour < 12 ? "AM" : "PM"
        var displayHour = hour % 12
        if displayHour == 0 { displayHour = 12 }
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(KeptFont.mono(10.5, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}
