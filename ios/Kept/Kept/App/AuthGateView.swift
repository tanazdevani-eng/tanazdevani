import SwiftUI

/// The actual app root: switches between the launch spinner, the phone sign-up/log-in
/// flow, the one-time post-signup onboarding step, and the real app, based on
/// AppModel.authStage. Nothing else in the app needs to know this switch exists — Log Out
/// and Delete Account just flip authStage back to .needsAuth and this reacts.
struct AuthGateView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        Group {
            switch appModel.authStage {
            case .checkingSession:
                LaunchLoadingView()
            case .needsAuth:
                NavigationStack { WelcomeView() }
            case .needsOnboarding:
                NavigationStack { OnboardingProfileView() }
            case .authenticated:
                RootTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appModel.authStage)
    }
}

/// Shown only while checkExistingSession() resolves at launch — the gap between the app
/// opening and knowing whether to show Welcome or the real app.
private struct LaunchLoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("Kept").keptWordmark(32).foregroundStyle(.keptInk)
            ProgressView().tint(.keptInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.keptBackground.ignoresSafeArea())
    }
}
