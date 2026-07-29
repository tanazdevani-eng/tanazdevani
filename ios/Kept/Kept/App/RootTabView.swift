import SwiftUI

enum RootTab: Hashable {
    case home, circle, profile
}

/// Root screen switcher using CustomTabBar instead of SwiftUI's stock TabView, to match
/// kept.html's floating pill tab bar exactly rather than the system's default chrome.
/// All three sections stay mounted simultaneously (toggled via opacity) so each keeps its
/// own navigation/scroll state when you switch away and back, instead of resetting.
/// Kept+ isn't a tab — it lives under Profile and opens as a sheet from anywhere
/// (AppModel.showingPaywall) since upsells fire from Home, Profile, and Streak Insights.
struct RootTabView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var showingAddHabit = false

    // Bumping a tab's reset token forces its NavigationStack (and everything pushed onto
    // it, plus any local @State in its screens) to be torn down and recreated from
    // scratch — tapping the already-active tab again does this, so it both pops back to
    // that tab's root AND clears any stale in-progress form state, in one move.
    @State private var homeResetToken = UUID()
    @State private var circleResetToken = UUID()
    @State private var profileResetToken = UUID()

    var body: some View {
        ZStack {
            section(.home) { NavigationStack { HomeView() }.id(homeResetToken) }
            section(.circle) { NavigationStack { CircleView() }.id(circleResetToken) }
            section(.profile) { NavigationStack { ProfileView() }.id(profileResetToken) }
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
            CustomTabBar(selection: $appModel.selectedTab, onAddTapped: {
                showingAddHabit = true
            }, onReselect: resetTab)
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
        .sheet(item: $appModel.goalCompletedHabit) { habit in
            GoalCompleteSheet(habit: habit)
        }
        .sheet(item: $appModel.incomingInvite) { invite in
            AcceptInviteView(invite: invite)
        }
        .sheet(isPresented: $appModel.showingPaywall) {
            NavigationStack { PaywallView() }
        }
    }

    @ViewBuilder
    private func section(_ tab: RootTab, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(appModel.selectedTab == tab ? 1 : 0)
            .allowsHitTesting(appModel.selectedTab == tab)
            .zIndex(appModel.selectedTab == tab ? 1 : 0)
    }

    private func resetTab(_ tab: RootTab) {
        switch tab {
        case .home: homeResetToken = UUID()
        case .circle: circleResetToken = UUID()
        case .profile: profileResetToken = UUID()
        }
    }
}
