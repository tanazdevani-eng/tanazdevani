import SwiftUI

struct ManageCircleView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddToCircle = false
    @State private var memberPendingRemoval: CircleMember?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(appModel.circleCount) people can see the habits you've marked Open.")
                    .font(KeptFont.body(13, weight: .medium))
                    .foregroundStyle(.keptInkSoft)

                sectionLabel("In your circle")
                ForEach(appModel.circleMembers) { member in
                    memberRow(member)
                }

                if !appModel.pendingInvites.isEmpty {
                    sectionLabel("Pending").padding(.top, 8)
                    ForEach(appModel.pendingInvites) { invite in
                        pendingRow(invite)
                    }
                }
            }
            .padding(22)
            .padding(.bottom, 90)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Manage Circle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddToCircle = true } label: {
                    Text("+").font(.system(size: 20, weight: .semibold)).foregroundStyle(.keptInk)
                }
            }
        }
        .navigationDestination(isPresented: $showingAddToCircle) {
            AddToCircleView()
        }
        .confirmationDialog(
            "Remove \(memberPendingRemoval?.name ?? "this person")?",
            isPresented: Binding(get: { memberPendingRemoval != nil }, set: { if !$0 { memberPendingRemoval = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let member = memberPendingRemoval {
                    appModel.removeMember(member)
                }
                memberPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { memberPendingRemoval = nil }
        }
    }

    private func memberRow(_ member: CircleMember) -> some View {
        HStack(spacing: 12) {
            AvatarView(initial: member.initial, seed: member.avatarSeed, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(member.name).font(KeptFont.body(13.5, weight: .bold)).foregroundStyle(.keptInk)
                Text("Sees \(member.openHabitCount) open habit\(member.openHabitCount == 1 ? "" : "s")")
                    .font(KeptFont.body(11, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
            }
            Spacer()
            // Danger-red, unlike a pending invite's "Cancel" below — removing an actual
            // member is a real, confirmed action with a consequence; canceling an invite
            // that was never accepted isn't, and the two used to look identical.
            Button("Remove") { memberPendingRemoval = member }
                .font(KeptFont.body(11.5, weight: .bold))
                .foregroundStyle(.keptDanger)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
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
            Button("Cancel") { appModel.cancelInvite(invite) }
                .font(KeptFont.body(11.5, weight: .bold))
                .foregroundStyle(.keptInkSoft)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(KeptFont.mono(10.5, weight: .semibold))
            .foregroundStyle(.keptInkSoft)
    }

    private func relativeDays(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days <= 0 { return "just now" }
        if days == 1 { return "1 day ago" }
        return "\(days) days ago"
    }
}
