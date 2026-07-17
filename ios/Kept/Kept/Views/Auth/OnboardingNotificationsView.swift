import SwiftUI

/// The "why we want this" screen before the system permission dialog — apps that explain
/// the ask first see meaningfully better opt-in than ones that fire the system prompt
/// cold. Either button proceeds; "Not now" just means the system dialog doesn't fire yet
/// (it can still be triggered later from Notifications settings).
struct OnboardingNotificationsView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Text("🔔")
                    .font(.system(size: 40))
                Text("Stay on track")
                    .font(KeptFont.display(22, weight: .semibold))
                    .foregroundStyle(.keptInk)
                Text("A quiet nudge at the right time is the difference between keeping a habit and forgetting it existed. We'll only remind you about what you ask us to.")
                    .font(KeptFont.body(13, weight: .medium))
                    .foregroundStyle(.keptInkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Spacer()

            VStack(spacing: 10) {
                Button("Enable notifications") {
                    appModel.requestNotificationPermission()
                    appModel.finishOnboarding()
                }
                .buttonStyle(KeptPillButtonStyle(background: .keptOrangeFill))

                Button("Not now") {
                    appModel.finishOnboarding()
                }
                .buttonStyle(KeptPillButtonStyle(background: .keptBackground, foreground: .keptInkSoft, borderColor: .keptLine))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}
