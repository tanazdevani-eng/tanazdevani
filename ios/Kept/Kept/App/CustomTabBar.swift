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
        // Two pairs flanking a fixed-width "+" — five items total lets it sit dead center
        // naturally (two tabs on each side) instead of needing an asymmetric split to fake
        // it, the way a 4-item bar would.
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                tabItem(.circle, glyph: "◎")
                tabItem(.groups, glyph: "⬡")
            }
            .frame(maxWidth: .infinity)

            addButton

            HStack(spacing: 0) {
                tabItem(.habits, glyph: "⌂")
                profileTabItem
            }
            .frame(maxWidth: .infinity)
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

    // No text label under the glyph anymore — the destination screen's own header
    // already spells out "Circle"/"Groups"/"Habits" in words the instant you land on it,
    // so the label here was just repeating what you're about to see.
    private func tabItem(_ tab: RootTab, glyph: String) -> some View {
        let isActive = selection == tab
        return Button {
            select(tab)
        } label: {
            Text(glyph)
                .font(.system(size: 23))
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
            AvatarView(initial: initial, seed: 0, size: 26, imageURL: avatarURL)
                .opacity(isActive ? 1 : 0.55)
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
    }
}
