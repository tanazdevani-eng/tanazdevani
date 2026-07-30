import SwiftUI
import UIKit

/// The Kept palette. Only orange (Open) and purple (Kept) carry meaning as accents —
/// never introduce a third accent color. Every token is light/dark aware; dark mode isn't
/// a flat gray inversion, it leans into a deep warm plum-black so the same "editorial
/// warmth" carries through instead of becoming a generic dark theme.
extension Color {
    static let keptBackground = Color(light: 0xFFFFFF, dark: 0x120E19)
    static let keptSurface = Color(light: 0xFFFFFF, dark: 0x1E1828)
    /// Solid fill for primary buttons/pills (checkin button, streak pill, "+"). Kept
    /// separate from `keptInk` on purpose: ink is page *text* and must lighten in dark
    /// mode for readability, but a button fill doesn't need to follow that same rule and
    /// inverting it to a pale pill would look wrong — this stays a dark, elevated neutral
    /// in both modes so filled buttons keep reading as solid, weighty surfaces.
    static let keptInkFill = Color(light: 0x211C24, dark: 0x2E2738)
    static let keptInk = Color(light: 0x211C24, dark: 0xF4EFEA)
    static let keptInkSoft = Color(light: 0x6B6470, dark: 0xAAA0B8)
    static let keptLine = Color(light: 0xECE4DA, dark: 0x2B2436)

    static let keptOrange = Color(light: 0xFF6A2C, dark: 0xFF7A42)
    static let keptOrangeDeep = Color(light: 0xE6551A, dark: 0xFFA36B)
    static let keptOrangeSoft = Color(light: 0xFFE3D0, dark: 0x3A2418)

    static let keptPurple = Color(light: 0x3E1969, dark: 0xA47FE0)
    static let keptPurpleDeep = Color(light: 0x2A1150, dark: 0xC9AEEF)
    static let keptPurpleSoft = Color(light: 0xE7DEF0, dark: 0x2A2140)

    static let keptSuccess = Color(light: 0x3EA05B, dark: 0x4ECB82)
    static let keptSuccessSoft = Color(light: 0xEAF6EE, dark: 0x173423)

    /// Semantic-only, like `keptSuccess` — not a third brand accent. Orange already means
    /// "Open" everywhere else in the app, so it can't also mean "destructive" without
    /// contradicting itself on screens like Delete account, where the two ideas would
    /// otherwise collide in the same color.
    static let keptDanger = Color(light: 0xC23B2E, dark: 0xE8695C)
    static let keptDangerSoft = Color(light: 0xFBEAE7, dark: 0x3A1E1A)

    /// Non-adaptive "always rich" accents for solid branded fills (paywall badge, featured
    /// plan card, invite-link card, Kept+ chip, destructive buttons) that must stay a deep,
    /// saturated color with white text on top in both modes — unlike `keptPurpleDeep`/
    /// `keptOrangeDeep`, which are meant to *lighten* in dark mode for legibility as small
    /// text sitting on their matching `Soft` tint. Using the adaptive versions for a solid
    /// fill would wash a branded card out to pale lavender/peach in dark mode.
    static let keptPurpleFill = Color(hex: 0x2A1150)
    static let keptOrangeFill = Color(hex: 0xE6551A)

    /// Neutral chip background (reaction button, comment field) — a step above the page
    /// background, a step below a full card surface.
    static let keptChip = Color(light: 0xF7F1E9, dark: 0x241F2E)

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Builds a color that automatically switches with the system's light/dark setting —
    /// the standard way to make a token dark-mode aware without needing `@Environment
    /// (\.colorScheme)` checks scattered through every view.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}

/// Mirrors every color above onto `ShapeStyle` so `.keptInk`-style dot-syntax also resolves
/// in APIs typed as `some ShapeStyle` (`.foregroundStyle(.keptInk)`, `.strokeBorder(.keptLine)`,
/// etc.) — a plain `extension Color` only satisfies call sites that ask for `Color` itself.
extension ShapeStyle where Self == Color {
    static var keptBackground: Color { .keptBackground }
    static var keptSurface: Color { .keptSurface }
    static var keptInkFill: Color { .keptInkFill }
    static var keptInk: Color { .keptInk }
    static var keptInkSoft: Color { .keptInkSoft }
    static var keptLine: Color { .keptLine }
    static var keptOrange: Color { .keptOrange }
    static var keptOrangeDeep: Color { .keptOrangeDeep }
    static var keptOrangeSoft: Color { .keptOrangeSoft }
    static var keptPurple: Color { .keptPurple }
    static var keptPurpleDeep: Color { .keptPurpleDeep }
    static var keptPurpleSoft: Color { .keptPurpleSoft }
    static var keptSuccess: Color { .keptSuccess }
    static var keptSuccessSoft: Color { .keptSuccessSoft }
    static var keptDanger: Color { .keptDanger }
    static var keptDangerSoft: Color { .keptDangerSoft }
    static var keptPurpleFill: Color { .keptPurpleFill }
    static var keptOrangeFill: Color { .keptOrangeFill }
    static var keptChip: Color { .keptChip }
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
            colors: [.keptSurface, accentSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var borderColor: Color {
        switch self {
        case .open: return Color(light: 0xFFD1B0, dark: 0x5C3620)
        case .kept: return Color(light: 0xD9C8EB, dark: 0x4A3866)
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

/// Groups already reuse the exact same orange/public vs. purple/private meaning as
/// HabitVisibility (see HabitGroup.swift) — giving them the identical gradient-card
/// treatment, not a separate flat style, is what makes Groups read as a native peer to
/// Habits/Circle instead of a plain utility screen bolted onto the app.
extension GroupVisibility {
    var accent: Color {
        switch self {
        case .publicGroup: return .keptOrange
        case .privateGroup: return .keptPurple
        }
    }

    /// For solid button fills specifically — same reasoning as keptOrangeFill/
    /// keptPurpleFill: `accent` above is adaptive and meant to *lighten* in dark mode for
    /// legibility as small text, so using it as a filled button's background would wash
    /// the button out to pale orange/lavender in dark mode instead of staying a solid fill.
    var accentFill: Color {
        switch self {
        case .publicGroup: return .keptOrangeFill
        case .privateGroup: return .keptPurpleFill
        }
    }

    var accentSoft: Color {
        switch self {
        case .publicGroup: return .keptOrangeSoft
        case .privateGroup: return .keptPurpleSoft
        }
    }

    var cardGradient: LinearGradient {
        LinearGradient(
            colors: [.keptSurface, accentSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var borderColor: Color {
        switch self {
        case .publicGroup: return Color(light: 0xFFD1B0, dark: 0x5C3620)
        case .privateGroup: return Color(light: 0xD9C8EB, dark: 0x4A3866)
        }
    }
}
