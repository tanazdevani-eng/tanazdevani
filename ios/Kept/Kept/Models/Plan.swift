import Foundation

enum Plan: String, Codable, Equatable {
    case free
    case keptPlus

    static let keptPlusMonthlyPrice: Decimal = 8.99
    static let freeHabitLimit = 3
    static let freeLockLimit = 1

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .keptPlus: return "Kept+"
        }
    }
}
