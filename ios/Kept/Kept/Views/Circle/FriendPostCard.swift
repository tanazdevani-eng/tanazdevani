import SwiftUI

struct FriendPostCard: View {
    @EnvironmentObject var appModel: AppModel
    let item: CircleFeedItem
    @State private var isPickingReaction = false
    @State private var commentText = ""
    @FocusState private var commentFocused: Bool
    @State private var showingMoreActions = false
    @State private var showingReportReasons = false
    @State private var showingBlockConfirm = false
    @State private var isEditingNote = false

    var body: some View {
        KeptCard(borderColor: item.isMine ? .keptOrange : .keptLine, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    AvatarView(initial: String(item.authorName.prefix(1)), seed: item.avatarSeed, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.isMine ? "You" : item.authorName)
                            .font(KeptFont.body(14, weight: .bold))
                            .foregroundStyle(.keptInk)
                        Text(item.timeLabel)
                            .font(KeptFont.body(11.5, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Text("🔥").font(.system(size: 12))
                        Text("\(item.streakCount)").font(KeptFont.mono(12.5, weight: .semibold))
                    }
                    .foregroundStyle(.keptInk)

                    if item.isMine, let habit = appModel.habits.first(where: { $0.id == item.habitId }) {
                        Button {
                            appModel.undoCheckIn(habit)
                        } label: {
                            Text("✕").font(.system(size: 13)).foregroundStyle(.keptInkSoft)
                        }
                        .padding(4)
                    } else if !item.isMine {
                        Button {
                            showingMoreActions = true
                        } label: {
                            Text("⋯")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.keptInkSoft)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                    }
                }

                if let habitName = item.habitName {
                    Text(habitName)
                        .font(KeptFont.display(16, weight: .semibold))
                        .foregroundStyle(.keptInk)
                }

                if let note = item.note, !note.isEmpty {
                    noteText("\u{201C}\(note)\u{201D}", italic: true)
                } else if item.isMine {
                    noteText("Checked in. No note this time.", italic: false)
                }

                HStack(spacing: 10) {
                    StreakDotsRow(filled: min(item.streakCount, 16), visibility: .open)
                    Text("\(item.streakCount) day\(item.streakCount == 1 ? "" : "s")")
                        .font(KeptFont.mono(11.5, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)
                }

                if let goal = item.goalDurationDays, let day = item.dayNumber {
                    goalProgressBar(day: day, goal: goal)
                }

                if !item.isMine {
                    Group {
                        if isPickingReaction {
                            ReactionPickerRow { emoji in
                                appModel.reactToFeedItem(item, emoji: emoji)
                                isPickingReaction = false
                            }
                        } else {
                            HStack(spacing: 8) {
                                Button {
                                    isPickingReaction = true
                                } label: {
                                    ReactionSummaryButton(reactions: item.reactions, myReactionEmoji: item.myReactionEmoji)
                                }
                                .buttonStyle(.plain)

                                if !item.hasCheckedInToday {
                                    let alreadyNudged = appModel.nudgedAuthorIds.contains(item.authorId)
                                    Button {
                                        appModel.nudge(item)
                                    } label: {
                                        Text(alreadyNudged ? "Nudged" : "Nudge")
                                            .font(KeptFont.body(13, weight: .semibold))
                                            .foregroundStyle(alreadyNudged ? .keptInkSoft : .keptOrangeDeep)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            // Matches the reaction button's neutral chip
                                            // background instead of orange-on-orange — the
                                            // color now lives only in the text, not doubled
                                            // up in the fill too.
                                            .background(Color.keptChip)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .disabled(alreadyNudged)
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: isPickingReaction)
                }

                commentsSection
            }
            .padding(16)
        }
        .confirmationDialog("\(item.authorName)", isPresented: $showingMoreActions, titleVisibility: .visible) {
            Button("Report post") { showingReportReasons = true }
            Button("Block \(item.authorName)", role: .destructive) { showingBlockConfirm = true }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Why are you reporting this?", isPresented: $showingReportReasons, titleVisibility: .visible) {
            ForEach(["Spam", "Inappropriate content", "Harassment", "Something else"], id: \.self) { reason in
                Button(reason) { appModel.reportPost(item, reason: reason) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Block \(item.authorName)?",
            isPresented: $showingBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) { appModel.blockUser(item) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to see your Open habits or check-ins anymore.")
        }
        .sheet(isPresented: $isEditingNote) {
            EditNoteSheet(initialText: item.note ?? "") { newNote in
                if let habit = appModel.habits.first(where: { $0.id == item.habitId }) {
                    appModel.updateNote(for: habit, note: newNote)
                }
            }
            .presentationDragIndicator(.visible)
        }
    }

    /// Tappable-to-edit for your own posts only — friends' notes are just text.
    @ViewBuilder
    private func noteText(_ text: String, italic: Bool) -> some View {
        let content = Text(text)
            .font(italic ? KeptFont.display(15.5, italic: true) : KeptFont.body(13, weight: .medium))
            .foregroundStyle(italic ? .keptInk : .keptInkSoft)
        if item.isMine {
            Button { isEditingNote = true } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    /// Only shown for habits with a duration goal (not Ongoing) — the streak dots above
    /// already say "how consistent," this says "how far into the goal," which a bare
    /// streak count doesn't capture on its own.
    private func goalProgressBar(day: Int, goal: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.keptChip)
                    Capsule()
                        .fill(item.isMine ? Color.keptOrange : Color.keptPurpleFill)
                        .frame(width: geo.size.width * CGFloat(day) / CGFloat(max(goal, 1)))
                }
            }
            .frame(height: 6)
            Text("Day \(day) of \(goal)")
                .font(KeptFont.mono(10.5, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.comments.isEmpty {
                Divider().overlay(Color.keptInk.opacity(0.08))
                ForEach(item.comments) { comment in
                    HStack(alignment: .top, spacing: 6) {
                        Text(comment.authorName)
                            .font(KeptFont.body(12, weight: .bold))
                            .foregroundStyle(.keptInk)
                        Text(comment.text)
                            .font(KeptFont.body(12, weight: .medium))
                            .foregroundStyle(.keptInkSoft)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add a comment...", text: $commentText)
                    .font(KeptFont.body(12.5))
                    .focused($commentFocused)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.keptChip)
                    .clipShape(Capsule())
                    .onSubmit { submitComment() }

                if !commentText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Post", action: submitComment)
                        .font(KeptFont.body(12.5, weight: .bold))
                        .foregroundStyle(.keptOrangeDeep)
                }
            }
        }
    }

    private func submitComment() {
        appModel.addComment(to: item, text: commentText)
        commentText = ""
        commentFocused = false
    }
}
