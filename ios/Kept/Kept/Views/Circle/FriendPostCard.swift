import SwiftUI

struct FriendPostCard: View {
    @EnvironmentObject var appModel: AppModel
    let item: CircleFeedItem
    @State private var isPickingReaction = false

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
                    }
                }

                if let note = item.note, !note.isEmpty {
                    Text("\u{201C}\(note)\u{201D}")
                        .font(KeptFont.display(15.5, italic: true))
                        .foregroundStyle(.keptInk)
                } else if item.isMine {
                    Text("Checked in. No note this time.")
                        .font(KeptFont.body(13, weight: .medium))
                        .foregroundStyle(.keptInkSoft)
                }

                if !item.isMine {
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
                                ReactionSummaryButton(reactions: item.reactions)
                            }
                            .buttonStyle(.plain)

                            if !item.hasCheckedInToday {
                                Button {
                                    appModel.nudge(item)
                                } label: {
                                    Text("👊 Nudge")
                                        .font(KeptFont.body(13, weight: .semibold))
                                        .foregroundStyle(.keptOrangeDeep)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(Color.keptOrangeSoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}
