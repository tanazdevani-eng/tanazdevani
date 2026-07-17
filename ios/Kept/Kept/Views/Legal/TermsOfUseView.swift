import SwiftUI

/// Functional Terms of Use, reachable from the Paywall — required near the purchase
/// button per Apple's Schedule 2 3.8(b). Placeholder legal language: have an actual
/// lawyer review this before shipping, especially the subscription and liability
/// sections, but it's real, reachable text, not a dead link.
struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Terms of Use")
                    .font(KeptFont.display(24, weight: .semibold))
                    .foregroundStyle(.keptInk)

                legalSection(
                    title: "Subscriptions",
                    body: "Kept+ is an auto-renewing subscription billed to your Apple ID at confirmation of purchase. Your subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period, at the price you agreed to when subscribing. You can manage or cancel your subscription any time in iPhone Settings → your name → Subscriptions. Any unused portion of a free trial, if offered, is forfeited when you purchase a subscription."
                )
                legalSection(
                    title: "Your content",
                    body: "You own what you post to Kept. Habits marked Kept are private and only ever visible to you. Habits marked Open are visible to the people in your Circle, and you're responsible for what you share there. Don't post anything you don't have the right to share, and don't use Kept to harass, threaten, or impersonate anyone. We can remove content and suspend accounts that violate this."
                )
                legalSection(
                    title: "Account",
                    body: "You're responsible for keeping your account secure. You can delete your account at any time from Profile → Delete account, which permanently removes your habits, streaks, and Circle history."
                )
                legalSection(
                    title: "Changes",
                    body: "We may update these terms as Kept evolves. Continuing to use the app after a change means you accept the update."
                )
                legalSection(
                    title: "Contact",
                    body: "Questions about these terms? Reach out through the support link on the App Store listing."
                )
            }
            .padding(22)
            .padding(.bottom, 60)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legalSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(KeptFont.body(14, weight: .bold))
                .foregroundStyle(.keptInk)
            Text(body)
                .font(KeptFont.body(13, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .lineSpacing(3)
        }
    }
}
