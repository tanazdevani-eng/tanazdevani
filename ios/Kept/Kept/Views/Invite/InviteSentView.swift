import SwiftUI

struct InviteSentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appModel: AppModel
    let contact: Contact

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.keptOrangeSoft)
                    Text("✓").font(.system(size: 32)).foregroundStyle(.keptOrangeDeep)
                }
                .frame(width: 72, height: 72)
                .padding(.top, 60)

                VStack(spacing: 8) {
                    Text("Share your invite with \(contact.name)")
                        .font(KeptFont.display(21, weight: .semibold))
                        .foregroundStyle(.keptInk)
                        .multilineTextAlignment(.center)
                    Text("It won't reach them until you send it. Tap below to share it over text, Mail, or however you'd like.")
                        .font(KeptFont.body(12.5, weight: .medium))
                        .foregroundStyle(.keptInkSoft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }

                Text("\u{201C}\(appModel.inviteShareMessage)\u{201D}")
                    .font(KeptFont.display(12.5, italic: true))
                    .foregroundStyle(.keptInk)
                    .padding(14)
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))

                ShareLink(item: appModel.inviteShareURL, message: Text(appModel.inviteShareMessage)) {
                    Text("Share the link")
                }
                .buttonStyle(.keptPrimary)
                .padding(.top, 4)

                Button("Maybe later") { dismiss() }
                    .buttonStyle(KeptPillButtonStyle(background: .keptBackground, foreground: .keptInkSoft, borderColor: .keptLine))
                    .padding(.top, 10)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 120)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}
