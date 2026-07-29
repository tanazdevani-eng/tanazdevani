import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var storeKit: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Plan = .keptPlus
    @State private var billingPeriod: BillingPeriod = .monthly
    @State private var showingManageSubscriptions = false
    @State private var isPurchasing = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false

    private enum BillingPeriod { case monthly, yearly }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                // Only shown once there's something the "KEPT+" pill above doesn't already
                // say — a plain "You're on Kept+" here would just repeat that pill forever.
                // A pending cancellation is genuinely new information, so that still shows.
                if storeKit.isSubscribed && !storeKit.willAutoRenew {
                    statusBanner.padding(.top, 16)
                }
                plans.padding(.top, 20)
                if selectedPlan == .keptPlus && !storeKit.isSubscribed {
                    billingToggle.padding(.top, 14)
                }
                cta.padding(.top, 24)
                footnote.padding(.top, 8)
                legalLinks.padding(.top, 10)

                if !storeKit.isSubscribed {
                    Button("Restore purchases") {
                        Task { await storeKit.restorePurchases() }
                    }
                    .font(KeptFont.body(12, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .background(Color.keptBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        // Presented as a sheet from Home/Profile/Streak Insights, not a tab root, so it
        // needs its own way out beyond a swipe-down.
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Text("✕")
                    .font(KeptFont.body(13, weight: .semibold))
                    .foregroundStyle(.keptInkSoft)
                    .frame(width: 30, height: 30)
                    .background(.keptSurface)
                    .clipShape(Circle())
            }
            .padding(.top, 14)
            .padding(.trailing, 18)
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .onChange(of: showingManageSubscriptions) { _, isPresented in
            // Canceling (or any other change) made inside that sheet doesn't push a
            // Transaction.updates event right away, so re-check renewal status the moment
            // it closes instead of leaving the banner showing stale info.
            if !isPresented {
                Task { await storeKit.refreshEntitlements() }
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { storeKit.lastError != nil },
            set: { if !$0 { storeKit.lastError = nil } }
        )) {
            Button("OK") { storeKit.lastError = nil }
        } message: {
            Text(storeKit.lastError ?? "")
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Text("KEPT+")
                .font(KeptFont.mono(10.5, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(Color.keptPurpleFill)
                .clipShape(Capsule())

            Text("Keep as much\nas you want.")
                .font(KeptFont.display(30, weight: .semibold))
                .foregroundStyle(.keptInk)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Text("Free keeps you honest with a few. Kept+ removes the limits: on habits and on privacy.")
                .font(KeptFont.body(13.5, weight: .medium))
                .foregroundStyle(.keptInkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.top, 20)
    }

    private var statusBanner: some View {
        Text(statusBannerText)
            .font(KeptFont.body(12, weight: .semibold))
            .foregroundStyle(.keptPurpleDeep)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.keptPurpleSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusBannerText: String {
        let base: String
        switch storeKit.activeProductID {
        case StoreKitManager.yearlyProductID: base = "You're currently on Kept+ Yearly."
        default: base = "You're currently on Kept+."
        }
        // Canceling stops the *next* renewal, it doesn't revoke access right away, so
        // without this someone who just canceled sees the exact same "You're on Kept+"
        // banner as before and assumes nothing happened.
        guard !storeKit.willAutoRenew, let renewalDate = storeKit.renewalDate else { return base }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(base) Won't renew. You'll move to Free on \(formatter.string(from: renewalDate))."
    }

    private var plans: some View {
        HStack(spacing: 10) {
            planCard(
                plan: .free,
                name: "Free",
                price: "$0",
                features: [("✓", "**3** active habits"), ("✓", "**1** private lock"), ("✓", "Circle access"), ("✕", "Streak insights")],
                featured: false
            )
            planCard(
                plan: .keptPlus,
                name: "Kept+",
                price: billingPeriod == .yearly ? storeKit.yearlyPriceText : storeKit.monthlyPriceText,
                priceSuffix: billingPeriod == .yearly ? "/yr" : "/mo",
                features: [("✓", "**Unlimited** habits"), ("✓", "**Unlimited** private locks"), ("✓", "Share with just a few people"), ("✓", "Streak insights")],
                featured: true
            )
        }
    }

    /// Only shown pre-purchase, once Kept+ is the selected card — lets you pick monthly
    /// vs. yearly before the purchase button fires. Defaults to yearly since it's the
    /// better value; nothing stops picking monthly instead.
    private var billingToggle: some View {
        HStack(spacing: 8) {
            billingOption(.monthly, label: "Monthly", price: "\(storeKit.monthlyPriceText)/mo")
            billingOption(.yearly, label: "Yearly", price: "\(storeKit.yearlyPriceText)/yr", badge: "SAVE 26%")
        }
    }

    private func billingOption(_ period: BillingPeriod, label: String, price: String, badge: String? = nil) -> some View {
        let isSelected = billingPeriod == period
        return Button {
            billingPeriod = period
        } label: {
            VStack(spacing: 4) {
                if let badge {
                    Text(badge)
                        .font(KeptFont.mono(8.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color.keptOrange)
                        .clipShape(Capsule())
                }
                Text(label).font(KeptFont.body(12.5, weight: .semibold))
                Text(price).font(KeptFont.mono(11, weight: .medium))
            }
            .foregroundStyle(isSelected ? .keptOrangeDeep : .keptInkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.keptOrangeSoft : Color.keptSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isSelected ? Color.keptOrange : Color.keptLine, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func planCard(plan: Plan, name: String, price: String, priceSuffix: String? = nil, features: [(String, String)], featured: Bool) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            guard storeKit.isSubscribed else {
                selectedPlan = plan
                return
            }
            // Already subscribed: tapping Free isn't just inert here — it's the one place
            // someone looking to downgrade would tap, so it should actually do something,
            // even though the only real "something" is pointing at iPhone Settings (Apple
            // doesn't allow an in-app cancel flow).
            if plan == .free {
                appModel.showToast("To move to Free, cancel Kept+ in iPhone Settings")
                showingManageSubscriptions = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if featured {
                    Text("MOST KEPT")
                        .font(KeptFont.mono(9.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 9)
                        .background(Color.keptOrange)
                        .clipShape(Capsule())
                }
                Text(name)
                    .font(KeptFont.display(15, weight: .semibold))
                    .foregroundStyle(featured ? .white : .keptInk)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price).font(KeptFont.mono(18, weight: .semibold))
                    if let priceSuffix {
                        Text(priceSuffix).font(KeptFont.body(11, weight: .medium))
                    }
                }
                .foregroundStyle(featured ? .white : .keptInk)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(features, id: \.1) { mark, text in
                        HStack(alignment: .top, spacing: 6) {
                            Text(mark)
                            Text(markdown(text))
                        }
                        .font(KeptFont.body(11.5, weight: .medium))
                        .foregroundStyle(featured ? Color(hex: 0xCBB9DF) : .keptInkSoft)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14))
            .background(featured ? Color.keptPurpleFill : Color.keptSurface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? Color.keptOrange : (featured ? Color.keptPurpleDeep : Color.keptLine), lineWidth: isSelected ? 2.5 : 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    @ViewBuilder private var cta: some View {
        if storeKit.isSubscribed {
            Button("Manage in iPhone Settings") { showingManageSubscriptions = true }
                .buttonStyle(KeptPillButtonStyle(background: .keptOrange))
        } else if selectedPlan == .keptPlus {
            Button {
                Task {
                    guard let product = billingPeriod == .yearly ? storeKit.yearlyProduct : storeKit.monthlyProduct else { return }
                    isPurchasing = true
                    await storeKit.purchase(product)
                    isPurchasing = false
                }
            } label: {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(billingPeriod == .yearly
                         ? "Continue (\(storeKit.yearlyPriceText)/yr)"
                         : "Continue (\(storeKit.monthlyPriceText)/mo)")
                }
            }
            .buttonStyle(KeptPillButtonStyle(background: .keptOrange))
            .disabled(isPurchasing)
        } else {
            Button("Continue with Free") {}
                .buttonStyle(KeptPillButtonStyle(background: .keptOrange))
                .disabled(true)
                .opacity(0.6)
        }
    }

    private var footnote: some View {
        Text(storeKit.isSubscribed
             ? "Subscription changes and cancellations happen through the App Store, not inside Kept."
             : "Payment will be charged to your Apple ID account at confirmation of purchase. Your subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period; your account will be charged for renewal within 24 hours before that. Manage or cancel any time in iPhone Settings.")
            .font(KeptFont.body(11, weight: .medium))
            .foregroundStyle(.keptInkSoft)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }

    private var legalLinks: some View {
        HStack(spacing: 14) {
            Button("Terms of Use") { showingTerms = true }
            Text("·").foregroundStyle(.keptInkSoft)
            Button("Privacy Policy") { showingPrivacy = true }
        }
        .font(KeptFont.body(11, weight: .semibold))
        .foregroundStyle(.keptInkSoft)
        .navigationDestination(isPresented: $showingTerms) { TermsOfUseView() }
        .navigationDestination(isPresented: $showingPrivacy) { PrivacyPolicyView() }
    }
}
