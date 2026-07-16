import SwiftUI

/// The Kept palette. Only orange (Open) and purple (Kept) carry meaning as accents —
/// never introduce a third accent color.
extension Color {
    static let keptBackground = Color(hex: 0xFBF6F0)
    static let keptInk = Color(hex: 0x211C24)
    static let keptInkSoft = Color(hex: 0x6B6470)
    static let keptLine = Color(hex: 0xECE4DA)

    static let keptOrange = Color(hex: 0xFF6A2C)
    static let keptOrangeDeep = Color(hex: 0xE6551A)
    static let keptOrangeSoft = Color(hex: 0xFFE3D0)

    static let keptPurple = Color(hex: 0x3E1969)
    static let keptPurpleDeep = Color(hex: 0x2A1150)
    static let keptPurpleSoft = Color(hex: 0xE7DEF0)

    static let keptSuccess = Color(hex: 0x3EA05B)
    static let keptSuccessSoft = Color(hex: 0xEAF6EE)

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension HabitVisibility {
    var accent: Color {
        switch self {
        case .open: return .keptOrange
        case .kept: return .keptPurple
        }
    }

    var accentDeep: Color {
        switch self {
        case .open: return .keptOrangeDeep
        case .kept: return .keptPurpleDeep
        }
    }

    var accentSoft: Color {
        switch self {
        case .open: return .keptOrangeSoft
        case .kept: return .keptPurpleSoft
        }
    }

    /// Card background gradient wash, matching kept.html's linear-gradient(155deg, white -> soft tint 130%).
    var cardGradient: LinearGradient {
        LinearGradient(
            colors: [.white, accentSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var borderColor: Color {
        switch self {
        case .open: return Color(hex: 0xFFD1B0)
        case .kept: return Color(hex: 0xD9C8EB)
        }
    }

    var label: String {
        switch self {
        case .open: return "Open"
        case .kept: return "Kept"
        }
    }

    /// Matches kept.html's literal "🌐 Open" / "🔒 Kept" pill glyph — this is the one
    /// intentional emoji use in the app, part of the visibility pill's copy itself.
    var pillGlyph: String {
        switch self {
        case .open: return "🌐"
        case .kept: return "🔒"
        }
    }
}
