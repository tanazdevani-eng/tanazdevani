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
                    Text("Invite sent to \(contact.name)")
                        .font(KeptFont.display(21, weight: .semibold))
                        .foregroundStyle(.keptInk)
                        .multilineTextAlignment(.center)
                    Text("We'll let you know the moment they join. You'll be able to add them to your circle right away.")
                        .font(KeptFont.body(12.5, weight: .medium))
                        .foregroundStyle(.keptInkSoft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
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
                        .font(KeptFont.body(13, weight: .bold))
                        .foregroundStyle(.keptOrangeDeep)
                }
                .padding(.top, 4)

                Button("Done") { dismiss() }
                    .buttonStyle(.keptPrimary)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 120)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}
