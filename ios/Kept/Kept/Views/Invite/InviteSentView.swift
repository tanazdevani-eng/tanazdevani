import SwiftUI

struct InviteSentView: View {
    @EnvironmentObject var appModel: AppModel
    let contact: Contact
    @State private var hasMarkedPending = false
    @State private var showingShareSheet = false

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

                Button("Share the link") { showingShareSheet = true }
                    .buttonStyle(.keptPrimary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 120)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        // A real UIActivityViewController, not ShareLink — ShareLink can't tell you
        // whether someone actually sent the share or backed out of the sheet, so it used
        // to mark Pending the instant the sheet opened. Cancel out of it here and nothing
        // happens; the button's still right there to try again. Only a genuine completion
        // marks Pending, and only once per visit to this screen (hasMarkedPending) so
        // sharing a second time doesn't create a duplicate pending invite for the same
        // contact.
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [appModel.inviteShareText]) { completed in
                guard completed, !hasMarkedPending else { return }
                hasMarkedPending = true
                appModel.sendInvite(to: contact)
            }
        }
    }
}
