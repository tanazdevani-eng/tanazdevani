import SwiftUI

/// Functional Privacy Policy, reachable from the Paywall — required near the purchase
/// button per Apple's Schedule 2 3.8(b), and separately required for App Privacy
/// disclosure. Placeholder language describing what Kept actually collects; have an
/// actual lawyer review before shipping.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Privacy Policy")
                    .font(KeptFont.display(24, weight: .semibold))
                    .foregroundStyle(.keptInk)

                legalSection(
                    title: "What we collect",
                    body: "Your phone number (for sign-in), your name, username, bio, and profile photo if you add one, the habits you create and their check-in history, and anything you post to your Circle (notes, reactions, comments)."
                )
                legalSection(
                    title: "What stays private",
                    body: "Habits marked Kept, and everything about them (name, streak, check-in history, notes), are never visible to anyone but you: not to friends in your Circle, not in any shared view. Only you can see them."
                )
                legalSection(
                    title: "What's shared",
                    body: "Habits marked Open, and the check-ins you post for them, are visible to the people in your Circle. If you restrict a habit to specific people, only they can see it, not your whole Circle."
                )
                legalSection(
                    title: "How it's used",
                    body: "Solely to run the app: showing your habits back to you, running the Circle feed, and sending the reminders you ask for. We don't sell your data or share it with advertisers."
                )
                legalSection(
                    title: "Payment",
                    body: "Kept+ subscriptions are billed and processed entirely by Apple through the App Store. We never see or store your payment details."
                )
                legalSection(
                    title: "Your control",
                    body: "You can edit or delete any habit, leave your Circle, or delete your account entirely at any time from Profile → Delete account, which permanently removes your data."
                )
                legalSection(
                    title: "Contact",
                    body: "Questions about this policy? Reach out through the support link on the App Store listing."
                )
            }
            .padding(22)
            .padding(.bottom, 60)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
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
