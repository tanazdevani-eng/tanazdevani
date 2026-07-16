import SwiftUI

enum RootTab: Hashable {
    case home, circle, add, paywall, profile
}

/// Tab bar matching kept.html's: Home / Circle / a center "+" that opens Add Habit as a
/// modal instead of becoming its own tab / Kept+ / You. Selecting `.add` is intercepted
/// below and immediately reverted, so the "+" never actually becomes the active tab.
struct RootTabView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var previousTab: RootTab = .home
    @State private var showingAddHabit = false

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(RootTab.home)

            NavigationStack { CircleView() }
                .tabItem { Label("Circle", systemImage: "circle.grid.2x2") }
                .tag(RootTab.circle)

            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(RootTab.add)

            NavigationStack { PaywallView() }
                .tabItem { Label("Kept+", systemImage: "sparkles") }
                .tag(RootTab.paywall)

            NavigationStack { ProfileView() }
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(RootTab.profile)
        }
        .tint(.keptInk)
        .onChange(of: appModel.selectedTab) { _, newValue in
            if newValue == .add {
                appModel.selectedTab = previousTab
                showingAddHabit = true
            } else {
                previousTab = newValue
            }
        }
        .sheet(isPresented: $showingAddHabit) {
            NavigationStack { AddHabitView() }
        }
        .overlay(alignment: .bottom) {
            if let toast = appModel.toast {
                KeptToast(message: toast)
                    .padding(.bottom, 90)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appModel.toast)
    }
}
