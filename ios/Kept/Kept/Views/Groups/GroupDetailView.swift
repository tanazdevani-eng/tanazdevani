import SwiftUI
import UIKit

struct GroupDetailView: View {
    @EnvironmentObject var appModel: AppModel
    let group: HabitGroup

    @State private var members: [GroupMemberInfo] = []
    @State private var feed: [GroupCheckIn] = []
    @State private var showingLogSheet = false
    @State private var showingEdit = false
    @State private var isLoading = true

    private var isMember: Bool { appModel.myGroups.contains { $0.id == group.id } }
    private var isCreator: Bool { group.creatorId == appModel.profile.id }

    /// Re-derived from appModel.myGroups rather than trusting `group` directly — `group` is
    /// a value captured at push time from the list row, so it goes stale the moment an edit
    /// saves (this screen never gets popped in between, just the Edit sheet dismissing back
    /// onto it). Falls back to `group` itself before the initial fetch populates myGroups.
    private var currentGroup: HabitGroup { appModel.myGroups.first(where: { $0.id == group.id }) ?? group }

    private var progress: [GroupMemberProgress] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -currentGroup.goalPeriod.days, to: Date()) ?? .distantPast
        var totals: [UUID: Double] = [:]
        for entry in feed where entry.loggedAt >= cutoff {
            totals[entry.memberId, default: 0] += entry.amount
        }
        let known = members.map {
            GroupMemberProgress(memberId: $0.id, memberName: $0.name, avatarSeed: $0.avatarSeed, amountThisPeriod: totals[$0.id] ?? 0)
        }
        return known.sorted { $0.amountThisPeriod > $1.amountThisPeriod }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                actionRow

                if !progress.isEmpty {
                    section("This \(currentGroup.goalPeriod.label)'s progress") {
                        VStack(spacing: 10) {
                            ForEach(progress) { member in
                                progressRow(member)
                            }
                        }
                    }
                }

                section("Activity") {
                    if feed.isEmpty {
                        Text(isLoading ? "Loading..." : "No one's logged progress yet.")
                            .font(KeptFont.body(12.5, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(feed) { entry in
                                GroupFeedRow(entry: entry) {
                                    Task { await load() }
                                }
                            }
                        }
                    }
                }
            }
            .padding(22)
            .padding(.bottom, 90)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle(currentGroup.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isCreator {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { showingEdit = true }
                        .font(KeptFont.body(13, weight: .semibold))
                        .foregroundStyle(.keptInk)
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingLogSheet) {
            LogGroupProgressSheet(group: currentGroup) {
                Task { await load() }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack { EditGroupView(group: currentGroup) }
        }
    }

    /// Same gradient-card treatment as a Habit card and the Groups list row, keyed off
    /// this group's own public/private visibility, rather than plain text sitting
    /// directly on the page background.
    private var header: some View {
        KeptCard(fill: AnyShapeStyle(currentGroup.visibility.cardGradient), borderColor: currentGroup.visibility.borderColor, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(currentGroup.visibility.pillGlyph) \(currentGroup.visibility.label)")
                    .font(KeptFont.mono(10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 9)
                    .background(currentGroup.visibility.accent)
                    .clipShape(Capsule())

                Text(currentGroup.locationLabel)
                    .font(KeptFont.body(13, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .padding(.top, 4)
                // Two different weights on one line, not one uniform-size string — the
                // activity is the headline, the cadence is a footnote next to it, not a
                // second half of the same sentence.
                Text(currentGroup.goalUnit)
                    .font(KeptFont.display(19, weight: .semibold))
                    .foregroundStyle(.keptInk)
                + Text("  ·  resets \(currentGroup.goalPeriod.adverb)")
                    .font(KeptFont.mono(11.5, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                Text("\(currentGroup.memberCount) member\(currentGroup.memberCount == 1 ? "" : "s")")
                    .font(KeptFont.mono(11, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 10) {
            if isMember {
                // Keyed to this group's own visibility, not always orange — a private
                // group's check-in button was using the same orange as "Open" everywhere
                // else, even though this group is the purple/private kind.
                Button("Check in") { showingLogSheet = true }
                    .buttonStyle(KeptPillButtonStyle(background: currentGroup.visibility.accentFill))

                if currentGroup.visibility == .privateGroup {
                    ShareLink(item: appModel.groupShareText(currentGroup)) {
                        Text("Share invite")
                            .font(KeptFont.body(13, weight: .bold))
                            .foregroundStyle(.keptInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.keptSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(.keptLine))
                    }
                }
            } else {
                Button("Join group") { Task { await appModel.joinGroup(currentGroup) } }
                    .buttonStyle(.keptPrimary)
            }
        }

        if isMember && !isCreator {
            Button("Leave group") { Task { await appModel.leaveGroup(currentGroup) } }
                .font(KeptFont.body(12, weight: .semibold))
                .foregroundStyle(.keptOrangeDeep)
        }
    }

    private func section(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(KeptFont.mono(11, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
            content()
        }
    }

    /// No more target to show a fraction against now that check-ins aren't numeric — the
    /// bar instead shows how each member stacks up against whoever's checked in the most
    /// this period, an honest relative comparison rather than a fictitious "X of Y" target.
    private var maxProgressThisPeriod: Double { max(progress.map(\.amountThisPeriod).max() ?? 1, 1) }

    private func progressRow(_ member: GroupMemberProgress) -> some View {
        let isMe = member.memberId == appModel.profile.id
        let count = Int(member.amountThisPeriod.rounded())
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(isMe ? "\(member.memberName) (you)" : member.memberName)
                    .font(KeptFont.body(13, weight: .semibold))
                    .foregroundStyle(.keptInk)
                Spacer()
                Text("\(count) check-in\(count == 1 ? "" : "s") this \(currentGroup.goalPeriod.label)")
                    .font(KeptFont.mono(11, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.keptChip)
                    Capsule()
                        .fill(Color.keptOrange)
                        .frame(width: geo.size.width * min(1, CGFloat(member.amountThisPeriod / maxProgressThisPeriod)))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(isMe ? Color.keptOrangeSoft : Color.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        // Easy to lose track of your own row in a busy leaderboard without this — every
        // other row looked identical regardless of who was you.
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isMe ? Color.keptOrange : Color.keptLine, lineWidth: isMe ? 1.5 : 1))
    }

    private func load() async {
        isLoading = true
        async let membersFetch = appModel.fetchGroupMembers(currentGroup)
        async let feedFetch = appModel.fetchGroupFeed(currentGroup)
        members = await membersFetch
        feed = await feedFetch
        isLoading = false
    }
}

private struct LogGroupProgressSheet: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let group: HabitGroup
    var onLogged: () -> Void

    @State private var note = ""
    @State private var isSaving = false
    @State private var capturedPhotos: [UIImage] = []
    private let maxPhotos = 2

    // Deliberately mirrors CheckInView's layout order (header, fixed gap, circle up top,
    // caption, form fields, save button) so a group check-in and a habit check-in feel
    // like the same screen, not two different flows that happen to share a camera widget.
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name).font(KeptFont.display(21, weight: .semibold)).foregroundStyle(.keptInk)
                        Text("Counts toward this \(group.goalPeriod.label)'s check-ins · tap the circle to capture a photo")
                            .font(KeptFont.body(12, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 6)

                    Spacer().frame(height: 28)

                    VStack(spacing: 14) {
                        LiveCameraCircle(ringColor: .keptOrange, isDisabled: capturedPhotos.count >= maxPhotos) { image in
                            capturedPhotos.append(image)
                        }
                        Text(capturedPhotos.isEmpty ? "TAP TO CAPTURE" : "TAP TO CAPTURE ANOTHER")
                            .font(KeptFont.mono(12, weight: .semibold))
                            .foregroundStyle(.keptInkSoft)

                        if !capturedPhotos.isEmpty {
                            Button("Retake last photo") { capturedPhotos.removeLast() }
                                .font(KeptFont.body(12, weight: .semibold))
                                .foregroundStyle(.keptOrangeDeep)
                        }
                    }
                    .padding(.top, 26)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ADD A NOTE ")
                            .font(KeptFont.mono(11, weight: .semibold))
                            .foregroundStyle(.keptInkSoft)
                        + Text("(optional)")
                            .font(KeptFont.body(11, weight: .regular))
                            .foregroundStyle(.keptInkSoft)

                        TextField("Say something about today...", text: $note, axis: .vertical)
                            .font(note.isEmpty ? KeptFont.body(13.5) : KeptFont.display(15))
                            .foregroundStyle(.keptInk)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(.keptSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.keptLine))
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { hideKeyboard() }
                                }
                            }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                    if !capturedPhotos.isEmpty {
                        photoRow
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                    }

                    Button(isSaving ? "Saving..." : "Save check-in") { save() }
                        .buttonStyle(.keptPrimary)
                        .padding(.horizontal, 22)
                        .padding(.top, 26)
                        .padding(.bottom, 30)
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.5 : 1)
                }
            }
            .background(Color.keptBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var photoRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(capturedPhotos.enumerated()), id: \.offset) { index, image in
                VStack(spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Button {
                            capturedPhotos.remove(at: index)
                        } label: {
                            Text("✕")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(.black.opacity(0.6)))
                        }
                        .padding(4)
                    }
                    Button("Save to Photos") {
                        Task {
                            let saved = await PhotoLibrarySaver.save(image)
                            appModel.showToast(saved ? "Saved to Photos" : "Couldn't save. Check Photos permission.")
                        }
                    }
                    .font(KeptFont.body(9.5, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func save() {
        isSaving = true
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            // Every check-in is worth 1, exactly like a personal habit — there's no
            // amount to type anymore, so this always logs the same way.
            await appModel.logGroupProgress(group, amount: 1, note: trimmedNote.isEmpty ? nil : trimmedNote, photos: capturedPhotos)
            isSaving = false
            onLogged()
            dismiss()
        }
    }
}
