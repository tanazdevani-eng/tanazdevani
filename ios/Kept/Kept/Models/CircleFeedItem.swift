import Foundation

/// One row in the Circle feed. For "you," one item exists per Open habit checked in today
/// (so undoing a check-in pulls exactly that card). For friends, one item represents their
/// most recent activity, with `hasCheckedInToday` gating whether Nudge or Reactions show —
/// nudging someone who has already checked in today doesn't make sense.
struct CircleFeedItem: Identifiable, Equatable {
    var id: UUID
    var authorId: UUID
    var authorName: String
    var avatarSeed: Int
    var isMine: Bool
    var habitId: UUID?
    var note: String?
    var timeLabel: String
    var streakCount: Int
    var hasCheckedInToday: Bool
    var reactions: [ReactionSummary]
    var myReactionEmoji: String?
    var comments: [Comment] = []

    var totalReactionCount: Int { reactions.reduce(0) { $0 + $1.count } }
}

struct ReactionSummary: Identifiable, Equatable {
    var emoji: String
    var count: Int
    var id: String { emoji }
}

enum ReactionEmoji: String, CaseIterable {
    case heart = "❤️"
    case fire = "🔥"
    case clap = "👏"
    case flex = "💪"
    case raisedHands = "🙌"
}
