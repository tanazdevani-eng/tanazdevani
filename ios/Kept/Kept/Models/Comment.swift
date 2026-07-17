import Foundation

struct Comment: Identifiable, Equatable {
    var id: UUID
    var authorName: String
    var text: String
    var postedAt: Date
}
