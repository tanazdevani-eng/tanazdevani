import Foundation

enum Plan: String, Codable, Equatable {
    case free
    case keptPlus

    static let keptPlusMonthlyPrice: Decimal = 8.99
    /// ~26% off the monthly-equivalent ($107.88/yr) - a real discount without being a
    /// race-to-the-bottom annual price, works out to about $6.67/mo.
    static let keptPlusYearlyPrice: Decimal = 79.99
    static let freeHabitLimit = 3
    static let freeLockLimit = 1

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .keptPlus: return "Kept+"
        }
    }
}
