import SwiftUI

/// Real emoji picker (❤️🔥👏💪🙌) shown in place of the react button on tap, matching
/// kept.html's .reaction-picker — plus a "+" that hands off to the system's own emoji
/// keyboard for anything outside that set. iOS has no public API to force-open the
/// emoji-only keyboard, so this focuses a plain text field; the standard globe/emoji key
/// on the keyboard is one tap away, same as picking an emoji anywhere else on the phone.
struct ReactionPickerRow: View {
    let onPick: (String) -> Void

    @State private var isEnteringCustom = false
    @State private var customText = ""
    @FocusState private var isCustomFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ReactionEmoji.allCases, id: \.self) { emoji in
                Text(emoji.rawValue)
                    .font(.system(size: 20))
                    .onTapGesture { onPick(emoji.rawValue) }
            }

            if isEnteringCustom {
                TextField("", text: $customText)
                    .focused($isCustomFocused)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20))
                    .frame(width: 36)
                    .onChange(of: customText) { _, newValue in
                        // Any character typed that isn't an emoji is discarded — this
                        // field exists only to reach the emoji keyboard, not to collect
                        // freeform text as a "reaction."
                        guard let last = newValue.last else { return }
                        if last.isEmoji {
                            onPick(String(last))
                        }
                        customText = ""
                        isEnteringCustom = false
                    }
            } else {
                Button {
                    isEnteringCustom = true
                    isCustomFocused = true
                } label: {
                    Text("+")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.keptInkSoft)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.keptChip)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.properties.isEmojiPresentation || unicodeScalars.count > 1)
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
        .background(Color.keptChip)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
