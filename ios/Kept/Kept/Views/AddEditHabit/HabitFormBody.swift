import SwiftUI

/// Shared body for Add Habit and Edit Habit — same fields, different chrome (Edit adds a
/// Delete action). Free tier shows a soft nudge about locks when Kept is picked but never
/// hard-blocks it; only the total habit count is hard-gated, and only on Add.
struct HabitFormBody: View {
    @EnvironmentObject var appModel: AppModel
    @Binding var name: String
    @Binding var visibility: HabitVisibility
    @Binding var duration: HabitDuration
    let saveLabel: String
    let onSave: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel("What are you keeping?")
            TextField("e.g. Read 20 pages", text: $name)
                .font(KeptFont.body(15))
                .padding(15)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))

            fieldLabel("Who sees it?").padding(.top, 16)
            VisibilityPicker(selection: $visibility)

            if visibility == .kept && appModel.isNearKeptLockLimit {
                lockBadge.padding(.top, 16)
            }

            fieldLabel("How long?").padding(.top, 16)
            DurationPicker(selection: $duration)

            Button(saveLabel, action: onSave)
                .buttonStyle(.keptPrimary)
                .padding(.top, 26)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

            if let onDelete {
                Button("Delete this habit", action: onDelete)
                    .font(KeptFont.body(13, weight: .bold))
                    .foregroundStyle(.keptOrangeDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
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

    private var lockBadge: some View {
        HStack(spacing: 8) {
            Text("✨")
            Text("Kept habits are limited on Free. Upgrade for unlimited locks.")
                .font(KeptFont.body(12, weight: .semibold))
        }
        .foregroundStyle(.keptPurpleDeep)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.keptPurpleSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
