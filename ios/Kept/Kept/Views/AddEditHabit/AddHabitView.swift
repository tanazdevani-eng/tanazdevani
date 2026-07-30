import SwiftUI

struct AddHabitView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var visibility: HabitVisibility = .open
    @State private var duration: HabitDuration = .ongoing
    @State private var sharedWithMemberIds: Set<UUID> = []

    var body: some View {
        ScrollView {
            HabitFormBody(
                name: $name,
                visibility: $visibility,
                duration: $duration,
                sharedWithMemberIds: $sharedWithMemberIds,
                saveLabel: "Save habit",
                onSave: save
            )
            .padding(22)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("New habit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear { visibility = appModel.defaultVisibility }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let added = appModel.addHabit(
            name: name.trimmingCharacters(in: .whitespaces), visibility: visibility, duration: duration,
            sharedWithMemberIds: sharedWithMemberIds
        )
        if added {
            dismiss()
        } else {
            appModel.paywallReason = "Free is limited to 3 habits. Kept+ removes the cap."
            appModel.showingPaywall = true
            dismiss()
        }
    }
}
