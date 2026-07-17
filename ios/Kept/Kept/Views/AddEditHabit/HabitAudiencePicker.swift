import SwiftUI

/// Kept+ only: pick a subset of your Circle who can see this specific Open habit, instead
/// of everyone — sharing an accountability habit with just Bobby instead of your whole
/// Circle. Still shows the orange "Open" pill either way; this doesn't add a third
/// visibility color or meaning, just narrows who "Open" actually reaches.
struct HabitAudiencePicker: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Set<UUID>

    var body: some View {
        List {
            Section {
                Button {
                    selection = []
                } label: {
                    HStack {
                        Text("Everyone in your Circle")
                            .font(KeptFont.body(14, weight: .semibold))
                            .foregroundStyle(.keptInk)
                        Spacer()
                        if selection.isEmpty {
                            Text("✓").foregroundStyle(.keptOrangeDeep)
                        }
                    }
                }
            }

            Section("Just these people") {
                ForEach(appModel.circleMembers) { member in
                    Button {
                        if selection.contains(member.id) {
                            selection.remove(member.id)
                        } else {
                            selection.insert(member.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(initial: member.initial, seed: member.avatarSeed, size: 30)
                            Text(member.name)
                                .font(KeptFont.body(14, weight: .semibold))
                                .foregroundStyle(.keptInk)
                            Spacer()
                            if selection.contains(member.id) {
                                Text("✓").foregroundStyle(.keptOrangeDeep)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Who sees this")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
