import SwiftUI
import UIKit

/// One entry in a group's activity feed — same social loop as a Circle post (reactions,
/// comments, photos) but for a numeric progress log instead of a binary check-in.
struct GroupFeedRow: View {
    @EnvironmentObject var appModel: AppModel
    let entry: GroupCheckIn
    let unit: String
    var onUpdate: () -> Void

    @State private var isPickingReaction = false
    @State private var commentText = ""
    @State private var commentPhoto: UIImage?
    @State private var showingCommentCamera = false
    @FocusState private var commentFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.memberName)
                    .font(KeptFont.body(13, weight: .bold))
                    .foregroundStyle(.keptInk)
                Spacer()
                Text("+\(formattedAmount(entry.amount)) \(unit)")
                    .font(KeptFont.mono(11.5, weight: .semibold))
                    .foregroundStyle(.keptOrangeDeep)
            }

            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(KeptFont.body(12, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
            }

            if !entry.photoURLs.isEmpty {
                HStack(spacing: 8) {
                    ForEach(entry.photoURLs, id: \.self) { url in
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.keptChip
                        }
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            Group {
                if isPickingReaction {
                    ReactionPickerRow { emoji in
                        appModel.reactToGroupCheckIn(entry, emoji: emoji)
                        isPickingReaction = false
                        onUpdate()
                    }
                } else {
                    Button {
                        isPickingReaction = true
                    } label: {
                        ReactionSummaryButton(reactions: entry.reactions, myReactionEmoji: entry.myReactionEmoji)
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isPickingReaction)

            commentsSection
        }
        .padding(12)
        .background(.keptSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.keptLine))
    }

    @ViewBuilder
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entry.comments.isEmpty {
                Divider().overlay(Color.keptInk.opacity(0.08))
                ForEach(entry.comments) { comment in
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
                            appModel.showToast(saved ? "Saved to Photos" : "Couldn't save — check Photos permission")
                        }
                    }
                    .font(KeptFont.body(9.5, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
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
                    // No .toolbar(.keyboard) here on purpose — this row repeats once per
                    // feed entry in a ForEach, and toolbar content is collected across the
                    // whole active hierarchy, not scoped per-row, so N of these would
                    // collide. The return key (onSubmit above) already posts the comment.

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
        let text = commentText
        let photo = commentPhoto
        commentText = ""
        commentPhoto = nil
        commentFocused = false
        Task {
            await appModel.addGroupComment(entry, text: text, photo: photo)
            onUpdate()
        }
    }

    private func formattedAmount(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
