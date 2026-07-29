import Foundation

/// One member's logged progress toward their group's shared goal on a given day —
/// the group equivalent of a Circle post, but numeric (an amount) instead of binary.
struct GroupCheckIn: Identifiable, Equatable {
    var id: UUID
    var groupId: UUID
    var memberId: UUID
    var memberName: String
    var avatarSeed: Int
    var amount: Double
    var note: String?
    var loggedAt: Date
    /// Camera-only, up to 2 — same shape as CircleFeedItem.photoURLs.
    var photoURLs: [URL] = []
    var comments: [Comment] = []
    var reactions: [ReactionSummary] = []
    var myReactionEmoji: String?
}

/// A bare member identity for a group's roster — separate from CircleMember since group
/// membership carries none of the Circle-specific state (invite status, habit counts).
struct GroupMemberInfo: Identifiable, Equatable {
    var id: UUID
    var name: String
    var avatarSeed: Int
}

/// A member's running total for the current goal period, derived client-side from a
/// group's recent GroupCheckIn history — drives each row's progress bar in GroupDetailView.
struct GroupMemberProgress: Identifiable {
    var memberId: UUID
    var memberName: String
    var avatarSeed: Int
    var amountThisPeriod: Double

    var id: UUID { memberId }
}
