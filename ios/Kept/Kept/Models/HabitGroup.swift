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
    /// "resets daily/weekly/monthly" — used now that the leaderboard is a plain check-in
    /// count rather than a number-of-units-per-period target.
    var adverb: String {
        switch self {
        case .daily: return "daily"
        case .weekly: return "weekly"
        case .monthly: return "monthly"
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

/// A location-tied public or private community around one shared thing members check
/// into together — distinct from a personal Habit only in that multiple people share it.
/// "NYC Runners" is a HabitGroup; each member just checks in like they would on a personal
/// habit (no number to type), and the group feed/leaderboard shows who's shown up and how
/// often this period, side by side.
struct HabitGroup: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var locationLabel: String
    var latitude: Double?
    var longitude: Double?
    /// Always 1 — every check-in counts as one, exactly like a personal habit. Kept as a
    /// stored amount (rather than removed) so the backend/leaderboard math (a sum of
    /// check-ins) doesn't need special-casing; there's just never a UI control for it.
    var goalAmount: Double
    /// What the group is doing together ("Run together", "Morning meditation") — free
    /// text, the same open-ended field as a personal habit's name, not a unit of measure.
    var goalUnit: String
    var goalPeriod: GroupGoalPeriod
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
        goalAmount: Double = 1,
        goalUnit: String,
        goalPeriod: GroupGoalPeriod = .weekly,
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
        self.visibility = visibility
        self.creatorId = creatorId
        self.createdAt = createdAt
        self.inviteToken = inviteToken
        self.memberCount = memberCount
    }

    /// "Run together · resets weekly" — no numbers, just what the group does and how
    /// often the leaderboard rolls over.
    var goalSummary: String {
        "\(goalUnit) · resets \(goalPeriod.adverb)"
    }
}
