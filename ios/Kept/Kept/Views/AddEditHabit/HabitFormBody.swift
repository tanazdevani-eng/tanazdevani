import SwiftUI

/// Shared body for Add Habit and Edit Habit — same fields, different chrome (Edit adds a
/// Delete action). Free tier shows a soft nudge about locks when Kept is picked but never
/// hard-blocks it; only the total habit count is hard-gated, and only on Add.
struct HabitFormBody: View {
    @EnvironmentObject var appModel: AppModel
    @Binding var name: String
    @Binding var visibility: HabitVisibility
    @Binding var duration: HabitDuration
    @Binding var sharedWithMemberIds: Set<UUID>
    let saveLabel: String
    let onSave: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var showingAudiencePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel("What are you keeping?")
            TextField("e.g. Read 20 pages", text: $name)
                .font(KeptFont.body(15))
                .padding(15)
                .background(.keptSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))

            fieldLabel("Who sees it?").padding(.top, 16)
            VisibilityPicker(selection: $visibility)

            // Shown as soon as Kept is picked, not just once the free lock is already
            // used up — creating your very first Kept habit used to get no preview at
            // all that a second one would need Kept+.
            if visibility == .kept && !appModel.isSubscribed {
                lockBadge.padding(.top, 16)
            }

            if visibility == .open {
                audienceRow.padding(.top, 12)
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
                    .foregroundStyle(.keptDanger)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            }
        }
        .sheet(isPresented: $showingAudiencePicker) {
            NavigationStack {
                HabitAudiencePicker(selection: $sharedWithMemberIds)
            }
        }
    }

    private var audienceLabel: String {
        sharedWithMemberIds.isEmpty ? "Everyone in your Circle" : "\(sharedWithMemberIds.count) person\(sharedWithMemberIds.count == 1 ? "" : "s")"
    }

    private var audienceRow: some View {
        Button {
            if appModel.isSubscribed {
                showingAudiencePicker = true
            } else {
                appModel.paywallReason = "Kept+ lets you share with just a few people instead of your whole circle."
                appModel.showingPaywall = true
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Who in your Circle?")
                        .font(KeptFont.body(13, weight: .semibold))
                        .foregroundStyle(.keptInk)
                    Text(appModel.isSubscribed ? audienceLabel : "Kept+ · share with just a few people")
                        .font(KeptFont.body(11.5, weight: .medium))
                        .foregroundStyle(appModel.isSubscribed ? .keptInkSoft : .keptPurpleDeep)
                }
                Spacer()
                Text("›").foregroundStyle(.keptInkSoft)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(.keptSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.keptLine))
        }
        .buttonStyle(.plain)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(KeptFont.mono(11, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }

    private var lockBadge: some View {
        Text(appModel.isNearKeptLockLimit
             ? "Kept habits are limited on Free. Upgrade for unlimited locks."
             : "This uses your one free Kept lock. Upgrade any time for unlimited.")
            .font(KeptFont.body(12, weight: .semibold))
            .foregroundStyle(.keptPurpleDeep)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.keptPurpleSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
