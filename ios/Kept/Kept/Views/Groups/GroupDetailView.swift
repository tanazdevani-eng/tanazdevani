import SwiftUI
import UIKit

struct GroupDetailView: View {
    @EnvironmentObject var appModel: AppModel
    let group: HabitGroup

    @State private var members: [GroupMemberInfo] = []
    @State private var feed: [GroupCheckIn] = []
    @State private var showingLogSheet = false
    @State private var isLoading = true

    private var isMember: Bool { appModel.myGroups.contains { $0.id == group.id } }

    private var progress: [GroupMemberProgress] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -group.goalPeriod.days, to: Date()) ?? .distantPast
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
                    section("This \(group.goalPeriod.label)'s progress") {
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
                                GroupFeedRow(entry: entry, unit: group.goalUnit) {
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
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showingLogSheet) {
            LogGroupProgressSheet(group: group) {
                Task { await load() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(group.visibility.pillGlyph)
                Text(group.visibility.label)
            }
            .font(KeptFont.mono(11, weight: .semibold))
            .foregroundStyle(.keptInkSoft)

            Text(group.locationLabel)
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
            Text(group.goalSummary)
                .font(KeptFont.display(19, weight: .semibold))
                .foregroundStyle(.keptInk)
            Text("\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")")
                .font(KeptFont.mono(11, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 10) {
            if isMember {
                Button("Check in") { showingLogSheet = true }
                    .buttonStyle(.keptAccent)

                if group.visibility == .privateGroup {
                    ShareLink(item: appModel.groupShareText(group)) {
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
                Button("Join group") { Task { await appModel.joinGroup(group) } }
                    .buttonStyle(.keptPrimary)
            }
        }

        if isMember && group.creatorId != appModel.profile.id {
            Button("Leave group") { Task { await appModel.leaveGroup(group) } }
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

    private func progressRow(_ member: GroupMemberProgress) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(member.memberName)
                    .font(KeptFont.body(13, weight: .semibold))
                    .foregroundStyle(.keptInk)
                Spacer()
                Text("\(formattedAmount(member.amountThisPeriod)) / \(formattedAmount(group.goalAmount)) \(group.goalUnit)")
                    .font(KeptFont.mono(11, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.keptChip)
                    Capsule()
                        .fill(Color.keptOrange)
                        .frame(width: geo.size.width * min(1, CGFloat(member.amountThisPeriod / max(group.goalAmount, 0.001))))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.keptLine))
    }

    private func formattedAmount(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func load() async {
        isLoading = true
        async let membersFetch = appModel.fetchGroupMembers(group)
        async let feedFetch = appModel.fetchGroupFeed(group)
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

    @State private var amountText = ""
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
                        Text("Adds to this \(group.goalPeriod.label)'s total · the circle is a live camera")
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
                        Text("AMOUNT ")
                            .font(KeptFont.mono(11, weight: .semibold))
                            .foregroundStyle(.keptInkSoft)
                        + Text("(optional, leave blank to count as 1)")
                            .font(KeptFont.body(10.5, weight: .regular))
                            .foregroundStyle(.keptInkSoft)
                        HStack(spacing: 8) {
                            TextField("1", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(KeptFont.body(15))
                                .padding(15)
                                .background(.keptSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.keptLine))
                            Text(group.goalUnit)
                                .font(KeptFont.body(14, weight: .medium))
                                .foregroundStyle(.keptInkSoft)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

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
                        .disabled(effectiveAmount == nil || isSaving)
                        .opacity(effectiveAmount == nil || isSaving ? 0.5 : 1)
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

    /// Typing a number is optional — leaving it blank (e.g. for a "did the workout or not"
    /// kind of goal) just logs 1, same simplicity as a personal habit check-in. Only an
    /// actual non-empty, non-numeric entry is treated as invalid.
    private var effectiveAmount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 1 }
        return Double(trimmed)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func save() {
        guard let amount = effectiveAmount else { return }
        isSaving = true
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await appModel.logGroupProgress(group, amount: amount, note: trimmedNote.isEmpty ? nil : trimmedNote, photos: capturedPhotos)
            isSaving = false
            onLogged()
            dismiss()
        }
    }
}
