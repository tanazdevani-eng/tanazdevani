import Foundation

struct CircleMember: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var avatarSeed: Int
    /// How many of this friend's habits are currently visible to me (Open, from their side).
    var openHabitCount: Int

    var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).first ?? "?").uppercased()
    }
}

struct PendingInvite: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var avatarSeed: Int
    var invitedAt: Date
}

enum InviteState: Equatable {
    case notInvited
    case pending
}

struct Contact: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var avatarSeed: Int
}
