import Foundation

/// Public groups are searchable/discoverable by anyone; private groups only join via a
/// shared link — same "shown to others vs. not" idea as HabitVisibility, deliberately
/// reusing the orange/purple accent pairing rather than inventing a third meaning for color.
enum GroupVisibility: String, Codable, CaseIterable, Identifiable, Hashable {
    case publicGroup = "public"
    case privateGroup = "private"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .publicGroup: return "Public"
        case .privateGroup: return "Private"
        }
    }

    var pickerDescription: String {
        switch self {
        case .publicGroup: return "Anyone can find and join by searching."
        case .privateGroup: return "Only joinable with a shared link."
        }
    }

    var pillGlyph: String {
        switch self {
        case .publicGroup: return "🌐"
        case .privateGroup: return "🔒"
        }
    }
}

/// One of a small set of periods the shared goal resets over.
enum GroupGoalPeriod: String, Codable, CaseIterable, Identifiable, Hashable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }
    var label: String {
        switch self {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        }
    }
    var days: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .monthly: return 30
        }
    }
}

/// Distinguishes "I did a measurable amount of something" (5 miles, 40 pages) — someone
/// types in a number each time — from "I just did the thing or I didn't" (a workout, a
/// meditation session) — a single tap logs it, same as a personal habit check-in. Not every
/// group goal is a quantity, so log-time behavior branches on this instead of forcing every
/// group through the numeric-amount flow.
enum GroupGoalKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case numeric
    case count

    var id: String { rawValue }
    var label: String {
        switch self {
        case .numeric: return "Track an amount"
        case .count: return "Track a count"
        }
    }
    var pickerDescription: String {
        switch self {
        case .numeric: return "Members type in how much they did — miles, pages, minutes."
        case .count: return "Members just tap check-in — workouts, sessions, days."
        }
    }
    var unitPlaceholder: String {
        switch self {
        case .numeric: return "Unit, e.g. miles"
        case .count: return "e.g. workouts, sessions"
        }
    }
}

/// A location-tied public or private community tracking one shared goal — distinct
/// from a personal Habit, which is binary done/not-done. "NYC Runners, 4 miles a week" is a
/// HabitGroup; each member logs their own amount toward that same shared goal (see
/// GroupCheckIn), and the group feed shows everyone's progress side by side.
struct HabitGroup: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var locationLabel: String
    var latitude: Double?
    var longitude: Double?
    var goalAmount: Double
    var goalUnit: String
    var goalPeriod: GroupGoalPeriod
    var goalKind: GroupGoalKind
    var visibility: GroupVisibility
    var creatorId: UUID
    var createdAt: Date
    var inviteToken: String
    var memberCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        locationLabel: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        goalAmount: Double,
        goalUnit: String,
        goalPeriod: GroupGoalPeriod = .weekly,
        goalKind: GroupGoalKind = .numeric,
        visibility: GroupVisibility,
        creatorId: UUID,
        createdAt: Date = Date(),
        inviteToken: String = UUID().uuidString,
        memberCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.locationLabel = locationLabel
        self.latitude = latitude
        self.longitude = longitude
        self.goalAmount = goalAmount
        self.goalUnit = goalUnit
        self.goalPeriod = goalPeriod
        self.goalKind = goalKind
        self.visibility = visibility
        self.creatorId = creatorId
        self.createdAt = createdAt
        self.inviteToken = inviteToken
        self.memberCount = memberCount
    }

    /// "4 mi / week"
    var goalSummary: String {
        let amountText = goalAmount == goalAmount.rounded() ? String(Int(goalAmount)) : String(goalAmount)
        return "\(amountText) \(goalUnit) / \(goalPeriod.label)"
    }
}
