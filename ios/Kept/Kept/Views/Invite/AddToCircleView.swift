import SwiftUI

struct AddToCircleView: View {
    @EnvironmentObject var appModel: AppModel

    @State private var searchText = ""
    @State private var copied = false
    @State private var invitedContact: Contact?

    private var filteredContacts: [Contact] {
        guard !searchText.isEmpty else { return appModel.contacts }
        return appModel.contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                fieldLabel("Share your link")
                inviteLinkCard

                fieldLabel("Find people").padding(.top, 20)
                TextField("🔍  Search by username or number", text: $searchText)
                    .font(KeptFont.body(14))
                    .padding(13)
                    .background(.keptSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(.keptLine))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                fieldLabel("From your contacts").padding(.top, 20)
                VStack(spacing: 10) {
                    ForEach(filteredContacts) { contact in
                        contactRow(contact)
                    }
                    ForEach(appModel.pendingInvites) { invite in
                        pendingRow(invite)
                    }
                }
            }
            .padding(22)
            .padding(.bottom, 90)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Add to Circle")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $invitedContact) { contact in
            InviteSentView(contact: contact)
        }
    }

    private var inviteLinkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR INVITE LINK")
                    .font(KeptFont.mono(10, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xC6B4DC))
                Text("kept.app/invite/\(appModel.profile.handle)")
                    .font(KeptFont.mono(12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Button(copied ? "Copied!" : "Copy") {
                    UIPasteboard.general.string = appModel.inviteShareURL.absoluteString
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        copied = false
                    }
                }
                .font(KeptFont.body(11.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .overlay(Capsule().strokeBorder(.white.opacity(0.5)))

                ShareLink(item: appModel.inviteShareText) {
                    Text("Share")
                        .font(KeptFont.body(11.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.keptOrange)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(17)
        .background(Color.keptPurpleFill)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func contactRow(_ contact: Contact) -> some View {
        HStack(spacing: 12) {
            AvatarView(initial: contact.name.prefix(1).uppercased(), seed: contact.avatarSeed, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(contact.name).font(KeptFont.body(13.5, weight: .bold)).foregroundStyle(.keptInk)
                Text("Not on Kept yet").font(KeptFont.body(11, weight: .medium)).foregroundStyle(.keptInkSoft)
            }
            Spacer()
            Button("Invite") {
                // Doesn't mark them Pending yet — that only happens once the share sheet
                // is actually engaged (see InviteSentView), not just from tapping this.
                invitedContact = contact
            }
            .font(KeptFont.body(11.5, weight: .bold))
            .foregroundStyle(.keptInk)
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .overlay(Capsule().strokeBorder(.keptInk, lineWidth: 1.5))
        }
        .padding(14)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))
    }

    private func pendingRow(_ invite: PendingInvite) -> some View {
        HStack(spacing: 12) {
            AvatarView(initial: invite.name.prefix(1).uppercased(), seed: invite.avatarSeed, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(invite.name).font(KeptFont.body(13.5, weight: .bold)).foregroundStyle(.keptInk)
                Text("Invited \(relativeDays(invite.invitedAt))").font(KeptFont.body(11, weight: .medium)).foregroundStyle(.keptInkSoft)
            }
            Spacer()
            Text("Pending")
                .font(KeptFont.body(11.5, weight: .bold))
                .foregroundStyle(.keptInkSoft)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(Color.keptBackground)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(.keptLine))
        }
        .padding(14)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))
    }

    private func relativeDays(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "just now" }
        if days == 1 { return "1 day ago" }
        return "\(days) days ago"
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(KeptFont.mono(11, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}
