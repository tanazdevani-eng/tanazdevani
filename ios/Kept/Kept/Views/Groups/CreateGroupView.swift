import SwiftUI

struct CreateGroupView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var locationLabel = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var goalUnit = ""
    @State private var goalPeriod: GroupGoalPeriod = .weekly
    @State private var visibility: GroupVisibility = .publicGroup
    @State private var isSaving = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !locationLabel.trimmingCharacters(in: .whitespaces).isEmpty
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

                // Open text, same as a personal habit's name field — no amount/unit split
                // to fill in. Every member just checks in, exactly like a habit; there's
                // nothing to type a number into anymore.
                fieldLabel("What's the shared goal?").padding(.top, 16)
                TextField("e.g. Run together, Morning meditation", text: $goalUnit)
                    .font(KeptFont.body(15))
                    .padding(15)
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                Text("Every member just checks in, like a habit. The group feed shows who's shown up and how often.")
                    .font(KeptFont.body(11.5, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .padding(.top, 6)

                fieldLabel("How often does the leaderboard reset?").padding(.top, 16)
                periodPicker

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

    /// Chip row, matching DurationPicker's preset style — a set of named choices, not a
    /// number field, so it doesn't read as "the numerical part" the way the old
    /// amount/unit/period row did.
    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(GroupGoalPeriod.allCases) { period in
                let isSelected = goalPeriod == period
                Button {
                    goalPeriod = period
                } label: {
                    Text(period.adverb.capitalized)
                        .font(KeptFont.body(12.5, weight: .semibold))
                        .foregroundStyle(isSelected ? .keptOrangeDeep : .keptInkSoft)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 14)
                        .background(isSelected ? Color.keptOrangeSoft : .keptSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(isSelected ? Color.keptOrange : Color.keptLine, lineWidth: isSelected ? 1.5 : 1))
                }
                .buttonStyle(.plain)
            }
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
        guard canSave else { return }
        isSaving = true
        Task {
            let created = await appModel.createGroup(
                name: name.trimmingCharacters(in: .whitespaces),
                locationLabel: locationLabel.trimmingCharacters(in: .whitespaces),
                latitude: latitude, longitude: longitude,
                goalUnit: goalUnit.trimmingCharacters(in: .whitespaces),
                goalPeriod: goalPeriod, visibility: visibility
            )
            isSaving = false
            if created != nil { dismiss() }
        }
    }
}
