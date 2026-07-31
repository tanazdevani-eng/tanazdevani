import SwiftUI
import UIKit

/// Two distinct layouts depending on whether a photo was captured, not one template every
/// post gets regardless of content: a photo makes this the feed's dominant, hero-sized
/// card (big image, overlay caption); no photo collapses to a compact single-card row.
/// Before this, every post — photo or not — rendered the exact same full-size template,
/// which is most of why the feed read as a stack of identical forms rather than a feed.
struct FriendPostCard: View {
    @EnvironmentObject var appModel: AppModel
    let item: CircleFeedItem
    @State private var isPickingReaction = false
    @State private var commentText = ""
    @State private var commentPhoto: UIImage?
    @State private var showingCommentCamera = false
    @FocusState private var commentFocused: Bool
    @State private var showingMoreActions = false
    @State private var showingReportReasons = false
    @State private var showingBlockConfirm = false
    @State private var isEditingNote = false
    @State private var isComposingComment = false

    private var hasPhoto: Bool { !item.photoURLs.isEmpty }

    var body: some View {
        KeptCard(borderColor: item.isMine ? .keptOrange : .keptLine, cornerRadius: hasPhoto ? 24 : 20) {
            if hasPhoto {
                VStack(alignment: .leading, spacing: 0) {
                    heroPhotoHeader
                    VStack(alignment: .leading, spacing: 12) {
                        postDetails
                        actionsAndComments
                    }
                    .padding(16)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    compactHeader
                    postDetails
                    actionsAndComments
                }
                .padding(14)
            }
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

    /// The big, hero-sized moment — a real captured photo fills the top of the card,
    /// bleeding to its rounded corners, with who/what overlaid directly on the image
    /// instead of a separate header row above it.
    private var heroPhotoHeader: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: item.photoURLs[0]) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.keptChip
            }
            .frame(height: 210)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(colors: [.black.opacity(0.62), .clear], startPoint: .bottom, endPoint: .top)
                .frame(height: 90)

            HStack(spacing: 8) {
                AvatarView(initial: String(item.authorName.prefix(1)), seed: item.avatarSeed, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.isMine ? "You" : item.authorName)
                        .font(KeptFont.body(13.5, weight: .bold))
                        .foregroundStyle(.white)
                    if let habitName = item.habitName {
                        Text("\(habitName) · \(item.timeLabel)")
                            .font(KeptFont.body(11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
            }
            .padding(12)
        }
        .overlay(alignment: .topTrailing) {
            postActionButton
                .padding(8)
                .background(.black.opacity(0.4))
                .clipShape(Circle())
                .padding(8)
        }
    }

    /// The whole card, compressed into one row — no image to anchor a big layout around,
    /// so this stays small: avatar, name, habit, streak, done.
    private var compactHeader: some View {
        HStack(spacing: 10) {
            AvatarView(initial: String(item.authorName.prefix(1)), seed: item.avatarSeed, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.isMine ? "You" : item.authorName)
                        .font(KeptFont.body(13.5, weight: .bold))
                        .foregroundStyle(.keptInk)
                    if item.status == .missed {
                        Text("DOWN DAY")
                            .font(KeptFont.mono(8.5, weight: .semibold))
                            .foregroundStyle(.keptInk)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Color.keptMuted)
                            .clipShape(Capsule())
                    }
                }
                if let habitName = item.habitName {
                    Text("\(habitName) · \(item.timeLabel)")
                        .font(KeptFont.body(11, weight: .medium))
                        .foregroundStyle(.keptInkSoft)
                }
            }
            Spacer()
            // A tintable symbol, not the 🔥 emoji — emoji carry their own fixed color
            // regardless of surrounding style and read as more visual noise than a
            // repeated small streak count needs, especially once it shows up on every row.
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").font(.system(size: 10))
                Text("\(item.streakCount)").font(KeptFont.mono(11.5, weight: .semibold))
            }
            .foregroundStyle(.keptInkSoft)
            postActionButton
        }
    }

    @ViewBuilder
    private var postActionButton: some View {
        if item.isMine, let habit = appModel.habits.first(where: { $0.id == item.habitId }) {
            Button {
                if item.status == .missed {
                    appModel.undoDownDay(habit)
                } else {
                    appModel.undoCheckIn(habit)
                }
            } label: {
                Text("✕")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hasPhoto ? .white : .keptInkSoft)
            }
            .padding(4)
        } else if !item.isMine {
            Button {
                showingMoreActions = true
            } label: {
                Text("⋯")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(hasPhoto ? .white : .keptInkSoft)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
        }
    }

    /// Down day tag (photo posts only — the compact header inlines it instead), note,
    /// streak dots, goal bar, and any photos past the first one. Shared by both layouts.
    @ViewBuilder
    private var postDetails: some View {
        if hasPhoto && item.status == .missed {
            Text("DOWN DAY")
                .font(KeptFont.mono(10, weight: .semibold))
                .foregroundStyle(.keptInk)
                .padding(.vertical, 4)
                .padding(.horizontal, 9)
                .background(Color.keptMuted)
                .clipShape(Capsule())
        }

        if let note = item.note, !note.isEmpty {
            noteText("\u{201C}\(note)\u{201D}", emphasized: true)
        }

        // Photo posts still get the fuller streak-dots treatment (there's room for it);
        // compact posts already show the count inline in the header, so repeating it here
        // would be the exact same redundancy that used to show the streak twice per post.
        if hasPhoto {
            HStack(spacing: 10) {
                StreakDotsRow(filled: min(item.streakCount, 16), visibility: .open)
                Text("\(item.streakCount) day\(item.streakCount == 1 ? "" : "s")")
                    .font(KeptFont.mono(11.5, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
            }
        }

        if let goal = item.goalDurationDays, let day = item.dayNumber {
            goalProgressBar(day: day, goal: goal)
        }

        if item.photoURLs.count > 1 {
            additionalPhotosRow
        }
    }

    @ViewBuilder
    private var actionsAndComments: some View {
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

                        // Never on a down-day post — they already told you they
                        // couldn't get to it, "nudge" reads as pestering, not
                        // support. Reactions/comments are the right response there.
                        if !item.hasCheckedInToday && item.status != .missed {
                            let alreadyNudged = appModel.nudgedAuthorIds.contains(item.authorId)
                            Button {
                                appModel.nudge(item)
                            } label: {
                                Text(alreadyNudged ? "Nudged" : "Nudge")
                                    .font(KeptFont.body(13, weight: .semibold))
                                    .foregroundStyle(alreadyNudged ? .keptInkSoft : .keptOrangeDeep)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
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

    /// Tappable-to-edit for your own posts only — friends' notes are just text.
    @ViewBuilder
    private func noteText(_ text: String, emphasized: Bool) -> some View {
        let content = Text(text)
            .font(emphasized ? KeptFont.display(15.5) : KeptFont.body(13, weight: .medium))
            .foregroundStyle(emphasized ? .keptInk : .keptInkSoft)
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
                        .fill(item.isMine ? Color.keptOrangeFill : Color.keptPurpleFill)
                        .frame(width: geo.size.width * CGFloat(day) / CGFloat(max(goal, 1)))
                }
            }
            .frame(height: 6)
            Text("Day \(day) of \(goal)")
                .font(KeptFont.mono(10.5, weight: .semibold))
                .foregroundStyle(.keptInkSoft)
        }
    }

    /// The first photo already anchors the hero header — this is only for a second shot,
    /// if there is one.
    private var additionalPhotosRow: some View {
        HStack(spacing: 10) {
            ForEach(item.photoURLs.dropFirst(), id: \.self) { url in
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.keptChip
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.comments.isEmpty {
                Divider().overlay(Color.keptInk.opacity(0.08))
                ForEach(item.comments) { comment in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 6) {
                            Text(comment.authorName)
                                .font(KeptFont.body(12, weight: .bold))
                                .foregroundStyle(.keptInk)
                            Text(comment.text)
                                .font(KeptFont.body(12, weight: .medium))
                                .foregroundStyle(.keptInkSoft)
                        }
                        if let photoURL = comment.photoURL {
                            AsyncImage(url: photoURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.keptChip
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }

            if let commentPhoto {
                VStack(alignment: .leading, spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: commentPhoto)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button {
                            self.commentPhoto = nil
                        } label: {
                            Text("✕")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(.black.opacity(0.6)))
                        }
                        .padding(3)
                    }
                    Button("Save to Photos") {
                        Task {
                            let saved = await PhotoLibrarySaver.save(commentPhoto)
                            appModel.showToast(saved ? "Saved to Photos" : "Couldn't save. Check Photos permission.")
                        }
                    }
                    .font(KeptFont.body(9.5, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                }
            }

            if isComposingComment || !commentText.isEmpty || commentPhoto != nil {
                HStack(spacing: 8) {
                    TextField("Add a comment...", text: $commentText)
                        .font(KeptFont.body(12.5))
                        .focused($commentFocused)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.keptChip)
                        .clipShape(Capsule())
                        .onSubmit { submitComment() }
                        // No .toolbar(.keyboard) here on purpose — this field repeats once per
                        // post in a ForEach, and SwiftUI toolbar content is collected across
                        // the whole active hierarchy, not scoped per-row, so N of these would
                        // collide. The return key (onSubmit above) already posts the comment.

                    // Camera only, no library import — same reasoning as check-in photos.
                    // A plain glyph rather than the word "Camera" — this is a single
                    // functional button, not a decorative icon grid, so it doesn't conflict
                    // with the app's "no icon library" rule.
                    if commentPhoto == nil && UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showingCommentCamera = true } label: {
                            Image(systemName: "camera")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.keptInkSoft)
                        }
                    }

                    if !commentText.trimmingCharacters(in: .whitespaces).isEmpty || commentPhoto != nil {
                        Button("Post", action: submitComment)
                            .font(KeptFont.body(12.5, weight: .bold))
                            .foregroundStyle(.keptOrangeDeep)
                    }
                }
            } else {
                Button {
                    isComposingComment = true
                    commentFocused = true
                } label: {
                    Text("Comment")
                        .font(KeptFont.body(12.5, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)
                }
                .buttonStyle(.plain)
            }
        }
        .fullScreenCover(isPresented: $showingCommentCamera) {
            CameraCaptureView(
                onCapture: { image in
                    commentPhoto = image
                    showingCommentCamera = false
                },
                onCancel: { showingCommentCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    private func submitComment() {
        appModel.addComment(to: item, text: commentText, photo: commentPhoto)
        commentText = ""
        commentPhoto = nil
        commentFocused = false
        isComposingComment = false
    }
}
