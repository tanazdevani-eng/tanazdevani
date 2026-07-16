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

struct ReactionSummaryButton: View {
    let reactions: [ReactionSummary]
    var body: some View {
        let top = reactions.max(by: { $0.count < $1.count })
        Text("\(top?.emoji ?? "❤️") \(reactions.reduce(0) { $0 + $1.count })")
            .font(KeptFont.body(13, weight: .semibold))
            .foregroundStyle(.keptInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color(hex: 0xF7F1E9))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
