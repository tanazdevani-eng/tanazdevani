import SwiftUI

struct EditHabitView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let habit: Habit

    @State private var name: String
    @State private var visibility: HabitVisibility
    @State private var duration: HabitDuration
    @State private var showingDeleteConfirm = false

    init(habit: Habit) {
        self.habit = habit
        _name = State(initialValue: habit.name)
        _visibility = State(initialValue: habit.visibility)
        _duration = State(initialValue: habit.duration)
    }

    var body: some View {
        ScrollView {
            HabitFormBody(
                name: $name,
                visibility: $visibility,
                duration: $duration,
                saveLabel: "Save changes",
                onSave: save,
                onDelete: { showingDeleteConfirm = true }
            )
            .padding(22)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Edit habit")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDeleteConfirm) {
            ConfirmSheetContent(
                title: "Delete \u{201C}\(habit.name)\u{201D}?",
                message: "This removes it from Home and Circle for good. Your streak history goes with it.",
                destructiveLabel: "Delete habit",
                onConfirm: {
                    showingDeleteConfirm = false
                    appModel.deleteHabit(habit)
                    dismiss()
                },
                onCancel: { showingDeleteConfirm = false }
            )
        }
    }

    private func save() {
        appModel.updateHabit(habit, name: name.trimmingCharacters(in: .whitespaces), visibility: visibility, duration: duration)
        dismiss()
    }
}
