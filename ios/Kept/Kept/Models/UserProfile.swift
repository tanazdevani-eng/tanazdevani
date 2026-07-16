import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var handle: String
    var bio: String
    var avatarURL: URL?

    init(id: UUID = UUID(), name: String, handle: String, bio: String, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.handle = handle
        self.bio = bio
        self.avatarURL = avatarURL
    }

    var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).first ?? "?").uppercased()
    }
}
