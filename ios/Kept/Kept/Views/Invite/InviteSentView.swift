import SwiftUI

struct InviteSentView: View {
    @EnvironmentObject var appModel: AppModel
    let contact: Contact
    @State private var hasMarkedPending = false

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
                    .font(KeptFont.display(12.5))
                    .foregroundStyle(.keptInk)
                    .padding(14)
                    .background(.keptSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))

                ShareLink(item: appModel.inviteShareText) {
                    Text("Share the link")
                }
                .buttonStyle(.keptPrimary)
                .padding(.top, 4)
                // Only marks Pending once the share sheet is actually engaged, not just
                // from reaching this screen — ShareLink has no "did the user actually send
                // it" completion callback, but this is the closest real signal of intent
                // there is, and simultaneousGesture doesn't interfere with ShareLink's own
                // tap handling that presents the system sheet.
                .simultaneousGesture(TapGesture().onEnded {
                    guard !hasMarkedPending else { return }
                    hasMarkedPending = true
                    appModel.sendInvite(to: contact)
                })
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 120)
        }
        .background(Color.keptBackground.ignoresSafeArea())
    }
}
