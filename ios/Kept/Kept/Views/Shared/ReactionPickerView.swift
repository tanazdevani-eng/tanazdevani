import SwiftUI

/// Real emoji picker (❤️🔥👏💪🙌) shown in place of the react button on tap, matching
/// kept.html's .reaction-picker — not a single fixed reaction.
struct ReactionPickerRow: View {
    let onPick: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ReactionEmoji.allCases, id: \.self) { emoji in
                Text(emoji.rawValue)
                    .font(.system(size: 20))
                    .onTapGesture { onPick(emoji.rawValue) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color(hex: 0xF7F1E9))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Shows every distinct emoji people reacted with, each with its own count (e.g. "❤️ 1
/// 😂 2"), not just a single collapsed winner — different people picking different
/// reactions should all show up, the way it works on basically every social app.
struct ReactionSummaryButton: View {
    let reactions: [ReactionSummary]
    let myReactionEmoji: String?

    private var sorted: [ReactionSummary] {
        reactions.sorted { $0.count > $1.count }
    }

    var body: some View {
        HStack(spacing: 6) {
            if reactions.isEmpty {
                Text("React")
                    .font(KeptFont.body(13, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
            } else {
                ForEach(sorted) { reaction in
                    HStack(spacing: 3) {
                        Text(reaction.emoji)
                        Text("\(reaction.count)")
                            .font(KeptFont.mono(11.5, weight: .semibold))
                    }
                    .foregroundStyle(reaction.emoji == myReactionEmoji ? .keptOrangeDeep : .keptInk)
                }
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color(hex: 0xF7F1E9))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
