import SwiftUI

/// Bottom confirm sheet matching kept.html's .confirm-overlay/.confirm-sheet — used for
/// delete habit, delete account, and log out.
struct ConfirmSheetContent: View {
    let title: String
    let message: String
    let destructiveLabel: String
    /// Log out is fully reversible (sign back in any time) and shouldn't carry the same
    /// visual weight as permanently deleting a habit or an account — only truly
    /// irreversible actions get the danger-red treatment; everything else reads as a
    /// normal confirm.
    var isDestructive: Bool = true
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KeptFont.display(18, weight: .semibold))
                .foregroundStyle(.keptInk)
            Text(message)
                .font(KeptFont.body(12.5, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .lineSpacing(3)
                .padding(.bottom, 12)

            Button(destructiveLabel, action: onConfirm)
                .buttonStyle(KeptPillButtonStyle(background: isDestructive ? .keptDanger : .keptInkFill))

            Button("Cancel", action: onCancel)
                .buttonStyle(KeptPillButtonStyle(background: .keptBackground, foreground: .keptInk, borderColor: .keptLine))
        }
        .padding(22)
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }
}
