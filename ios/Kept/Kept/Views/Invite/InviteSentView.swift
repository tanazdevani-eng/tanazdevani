import SwiftUI

struct InviteSentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appModel: AppModel
    let contact: Contact

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.keptOrangeSoft)
                    Text("✓").font(.system(size: 32)).foregroundStyle(.keptOrangeDeep)
                }
                .frame(width: 72, height: 72)

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

                Text("\u{201C}Hey! I'm using Kept to stay on track with my habits. Join my circle: \(inviteLink)\u{201D}")
                    .font(KeptFont.display(12.5, italic: true))
                    .foregroundStyle(.keptInk)
                    .padding(14)
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
            }
            .padding(.horizontal, 30)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.keptPrimary)
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private var inviteLink: String { "kept.app/invite/\(appModel.profile.handle)" }
}
