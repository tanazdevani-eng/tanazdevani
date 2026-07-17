import SwiftUI

/// Hand-built floating pill tab bar, matching kept.html's `.tabbar` exactly: frosted glass,
/// 26px corner radius, a black circular "+" in the middle. Deliberately not using SwiftUI's
/// stock TabView — on iOS 26 it draws its own prominent "Liquid Glass" blur bubble behind
/// the selected item that can't be turned off and doesn't match this design at all.
struct CustomTabBar: View {
    @EnvironmentObject var appModel: AppModel
    @Binding var selection: RootTab
    var onAddTapped: () -> Void
    /// Fires when the *already active* tab is tapped again — RootTabView uses this to
    /// pop that tab back to its root and clear any in-progress state, matching the usual
    /// "tap the tab you're already on to reset it" pattern.
    var onReselect: (RootTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home, glyph: "⌂", label: "Home")
            tabItem(.circle, glyph: "◎", label: "Circle")
            addButton
            tabItem(.paywall, glyph: "✦", label: "Kept+")
            profileTabItem
        }
        .frame(height: 74)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .background(Color.keptSurface.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.keptSurface.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func select(_ tab: RootTab) {
        if selection == tab {
            onReselect(tab)
        } else {
            selection = tab
        }
    }

    private func tabItem(_ tab: RootTab, glyph: String, label: String) -> some View {
        let isActive = selection == tab
        return Button {
            select(tab)
        } label: {
            VStack(spacing: 4) {
                Text(glyph).font(.system(size: 19))
                Text(label).font(KeptFont.body(9.5, weight: .bold))
            }
            .foregroundStyle(isActive ? Color.keptInk : Color(light: 0xB7ADC0, dark: 0x5C5568))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    /// Shows your own avatar instead of a generic glyph — matches how most social apps
    /// mark the "you" tab, and sidesteps needing a symbol that reads as "person" while
    /// visually matching the weight of the other three geometric glyphs.
    private var profileTabItem: some View {
        let isActive = selection == .profile
        let initial = appModel.profile.initial
        let avatarURL = appModel.profile.avatarURL
        return Button {
            select(.profile)
        } label: {
            VStack(spacing: 4) {
                AvatarView(initial: initial, seed: 0, size: 19, imageURL: avatarURL)
                    .opacity(isActive ? 1 : 0.55)
                Text("You").font(KeptFont.body(9.5, weight: .bold))
            }
            .foregroundStyle(isActive ? Color.keptInk : Color(light: 0xB7ADC0, dark: 0x5C5568))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button(action: onAddTapped) {
            Text("+")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color.keptInkFill)
                        // keptInkFill sits too close in value to the blurred tab bar
                        // background in dark mode without this — the circle's edge was
                        // nearly invisible, leaving just the "+" glyph floating on its own.
                        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
                )
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                .padding(.bottom, 1)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
