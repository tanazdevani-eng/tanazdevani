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
    var habitName: String?
    var note: String?
    var timeLabel: String
    var streakCount: Int
    /// Non-nil only for habits with a duration goal (not Ongoing) — drives the "Day 12 of
    /// 30" progress bar on the post. `dayNumber` is already clamped to `goalDurationDays`.
    var goalDurationDays: Int?
    var dayNumber: Int?
    /// `.missed` is a "down day" post — logged on purpose, not silence, so it still shows
    /// up here just like `.done`, but Nudge never applies to it (see FriendPostCard) and
    /// it renders without the streak-continues framing.
    var status: PostStatus = .done
    var hasCheckedInToday: Bool
    var reactions: [ReactionSummary]
    var myReactionEmoji: String?
    var comments: [Comment] = []
    /// Up to 2 photos attached at check-in — not a forced simultaneous front/back pair,
    /// just an optional attachment (see CheckInView).
    var photoURLs: [URL] = []

    var totalReactionCount: Int { reactions.reduce(0) { $0 + $1.count } }
}

enum PostStatus: Equatable {
    case done
    case missed
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
