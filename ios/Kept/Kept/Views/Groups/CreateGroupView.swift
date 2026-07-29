import SwiftUI

struct CreateGroupView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var locationLabel = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var goalAmountText = "4"
    @State private var goalUnit = "miles"
    @State private var goalPeriod: GroupGoalPeriod = .weekly
    @State private var visibility: GroupVisibility = .publicGroup
    @State private var isSaving = false

    private var goalAmount: Double? { Double(goalAmountText) }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !locationLabel.trimmingCharacters(in: .whitespaces).isEmpty
            && (goalAmount ?? 0) > 0
            && !goalUnit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                fieldLabel("Group name")
                TextField("e.g. NYC Runners", text: $name)
                    .font(KeptFont.body(15))
                    .padding(15)
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))

                fieldLabel("Location").padding(.top, 16)
                LocationField(label: $locationLabel, latitude: $latitude, longitude: $longitude)

                fieldLabel("Shared goal").padding(.top, 16)
                HStack(spacing: 10) {
                    TextField("Amount", text: $goalAmountText)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    TextField("Unit, e.g. miles", text: $goalUnit)
                    periodMenu
                }
                .font(KeptFont.body(14))
                .padding(15)
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                Text("Every member logs their own progress toward this same goal — leave it blank at check-in and it just counts as 1, no typing required if it's not a number thing (like a workout).")
                    .font(KeptFont.body(11.5, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .padding(.top, 6)

                fieldLabel("Who can find this group?").padding(.top, 16)
                visibilityPicker

                Button(isSaving ? "Creating..." : "Create group") { save() }
                    .buttonStyle(.keptPrimary)
                    .padding(.top, 26)
                    .padding(.bottom, 30)
                    .disabled(!canSave || isSaving)
                    .opacity(!canSave || isSaving ? 0.5 : 1)
            }
            .padding(22)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("New group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private var periodMenu: some View {
        Menu {
            ForEach(GroupGoalPeriod.allCases) { period in
                Button("per \(period.label)") { goalPeriod = period }
            }
        } label: {
            Text("/ \(goalPeriod.label)")
                .foregroundStyle(.keptInkSoft)
        }
    }

    private var visibilityPicker: some View {
        HStack(spacing: 10) {
            ForEach(GroupVisibility.allCases) { option in
                Button {
                    visibility = option
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(option.pillGlyph).font(.system(size: 20))
                        Text(option.label)
                            .font(KeptFont.display(14.5, weight: .semibold))
                            .foregroundStyle(.keptInk)
                        Text(option.pickerDescription)
                            .font(KeptFont.body(11.5, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14))
                    .background(visibility == option ? (option == .publicGroup ? Color.keptOrangeSoft : Color.keptPurpleSoft) : .keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(visibility == option ? (option == .publicGroup ? Color.keptOrange : Color.keptPurple) : Color.keptLine, lineWidth: visibility == option ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(KeptFont.mono(11, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    private func save() {
        guard let amount = goalAmount, canSave else { return }
        isSaving = true
        Task {
            let created = await appModel.createGroup(
                name: name.trimmingCharacters(in: .whitespaces),
                locationLabel: locationLabel.trimmingCharacters(in: .whitespaces),
                latitude: latitude, longitude: longitude,
                goalAmount: amount, goalUnit: goalUnit.trimmingCharacters(in: .whitespaces),
                goalPeriod: goalPeriod, visibility: visibility
            )
            isSaving = false
            if created != nil { dismiss() }
        }
    }
}
