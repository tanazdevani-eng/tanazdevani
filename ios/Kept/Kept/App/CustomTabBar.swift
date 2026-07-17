import SwiftUI

/// Hand-built floating pill tab bar, matching kept.html's `.tabbar` exactly: frosted glass,
/// 26px corner radius, a black circular "+" in the middle. Deliberately not using SwiftUI's
/// stock TabView — on iOS 26 it draws its own prominent "Liquid Glass" blur bubble behind
/// the selected item that can't be turned off and doesn't match this design at all.
struct CustomTabBar: View {
    @Binding var selection: RootTab
    var onAddTapped: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.home, glyph: "⌂", label: "Home")
            tabItem(.circle, glyph: "◎", label: "Circle")
            addButton
            tabItem(.paywall, glyph: "✦", label: "Kept+")
            tabItem(.profile, glyph: "☺", label: "You")
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
        .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
    }

    private func tabItem(_ tab: RootTab, glyph: String, label: String) -> some View {
        let isActive = selection == tab
        return Button {
            selection = tab
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

    private var addButton: some View {
        Button(action: onAddTapped) {
            Text("+")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.keptInkFill))
                .padding(.bottom, 1)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
