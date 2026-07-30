import SwiftUI

/// Full-width pill button, ~100px radius, matches kept.html's .primary-btn / .checkin-btn / .paywall-cta.
///
/// Color rule: `.keptPrimary` (ink) is the default for routine in-app actions — Save,
/// Create, Continue once you're already a user. Orange (`.keptOrangeFill`) is reserved for
/// the actual conversion moments: Sign Up, Verify, Accept Invite, Paywall's Continue —
/// screens whose whole job is getting someone to say yes to something new, where the
/// brighter color earns its emphasis instead of being the default everywhere.
struct KeptPillButtonStyle: ButtonStyle {
    var background: Color = .keptInkFill
    var foreground: Color = .white
    var borderColor: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KeptFont.body(15, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(background)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(borderColor ?? .clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == KeptPillButtonStyle {
    static var keptPrimary: KeptPillButtonStyle { KeptPillButtonStyle() }
}

/// Card container: large radius, hairline border, matches .habit-card / .friend-card / .member-row.
struct KeptCard<Content: View>: View {
    var fill: AnyShapeStyle
    var borderColor: Color
    var cornerRadius: CGFloat
    @ViewBuilder var content: Content

    init(
        fill: AnyShapeStyle = AnyShapeStyle(Color.keptSurface),
        borderColor: Color = .keptLine,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }
}

/// Small rounded pill used for visibility toggles ("🌐 Open" / "🔒 Kept").
struct VisibilityPill: View {
    let visibility: HabitVisibility
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(visibility.pillGlyph) \(visibility.label)")
                .font(KeptFont.mono(10.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(visibility.accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Streak progress dots, up to 16 shown, matches .dots/.dot.filled.
struct StreakDotsRow: View {
    let filled: Int
    let visibility: HabitVisibility
    let total: Int = 16

    var body: some View {
        HStack(spacing: 3.5) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? visibility.accent : Color.keptLine)
                    .frame(width: 7, height: 7)
            }
        }
    }
}

struct KeptToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(KeptFont.body(12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, 18)
            .background(Color.keptInkFill)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
    }
}
