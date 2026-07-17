import SwiftUI

enum RootTab: Hashable {
    case home, circle, paywall, profile
}

/// Root screen switcher using CustomTabBar instead of SwiftUI's stock TabView, to match
/// kept.html's floating pill tab bar exactly rather than the system's default chrome.
/// All four sections stay mounted simultaneously (toggled via opacity) so each keeps its
/// own navigation/scroll state when you switch away and back, instead of resetting.
struct RootTabView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddHabit = false

    var body: some View {
        ZStack {
            section(.home) { NavigationStack { HomeView() } }
            section(.circle) { NavigationStack { CircleView() } }
            section(.paywall) { NavigationStack { PaywallView() } }
            section(.profile) { NavigationStack { ProfileView() } }
        }
        // Reserves room above the floating tab bar for every screen at once — including
        // pushed ones like Invite Sent — so nothing (buttons especially) ever ends up
        // rendered underneath it, unreachable. Individual screens don't need to know
        // about the tab bar's height at all.
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 90)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            CustomTabBar(selection: $appModel.selectedTab) {
                showingAddHabit = true
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = appModel.toast {
                KeptToast(message: toast)
                    .padding(.bottom, 90)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appModel.toast)
        .sheet(isPresented: $showingAddHabit) {
            NavigationStack { AddHabitView() }
        }
        .overlay {
            if !appModel.hasCompletedInitialLoad {
                LaunchLoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appModel.hasCompletedInitialLoad)
    }

    @ViewBuilder
    private func section(_ tab: RootTab, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(appModel.selectedTab == tab ? 1 : 0)
            .allowsHitTesting(appModel.selectedTab == tab)
            .zIndex(appModel.selectedTab == tab ? 1 : 0)
    }
}

/// Shown only for the very first bootstrap() — the gap between app launch and the first
/// habits/profile fetch resolving, so the tab bar and empty content don't flash briefly
/// before real data arrives.
private struct LaunchLoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("Kept").keptWordmark(32).foregroundStyle(.keptInk)
            ProgressView().tint(.keptInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.keptBackground)
    }
}
