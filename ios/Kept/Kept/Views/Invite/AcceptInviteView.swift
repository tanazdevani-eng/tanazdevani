import SwiftUI

/// Shown as a sheet from RootTabView whenever appModel.incomingInvite is set — the
/// accept-side of a kept://invite link, reached either by tapping a shared link directly
/// or by finishing sign-up/log-in after tapping one while signed out.
struct AcceptInviteView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let invite: IncomingInvite

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            AvatarView(initial: String(invite.inviterName.prefix(1)), seed: abs(invite.inviterName.hashValue) % 6, size: 72)

            VStack(spacing: 8) {
                Text("\(invite.inviterName) wants to circle up")
                    .font(KeptFont.display(22, weight: .semibold))
                    .foregroundStyle(.keptInk)
                    .multilineTextAlignment(.center)
                Text("Accepting adds you to each other's Circle. You'll see their Open habits, and they'll see yours.")
                    .font(KeptFont.body(13, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 270)
            }

            Spacer()

            VStack(spacing: 10) {
                Button("Accept") {
                    appModel.acceptIncomingInvite()
                    dismiss()
                }
                .buttonStyle(KeptPillButtonStyle(background: .keptOrangeFill))

                Button("Not now") {
                    appModel.declineIncomingInvite()
                    dismiss()
                }
                .buttonStyle(KeptPillButtonStyle(background: .keptBackground, foreground: .keptInkSoft, borderColor: .keptLine))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .background(Color.keptBackground.ignoresSafeArea())
    }
}
