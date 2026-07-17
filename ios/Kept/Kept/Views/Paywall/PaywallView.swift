import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var storeKit: StoreKitManager
    @State private var selectedPlan: Plan = .keptPlus
    @State private var showingManageSubscriptions = false
    @State private var isPurchasing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                if storeKit.isSubscribed {
                    statusBanner.padding(.top, 16)
                }
                plans.padding(.top, 20)
                cta.padding(.top, 24)
                footnote.padding(.top, 8)

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
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
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
        Text("You're currently on Kept+.")
            .font(KeptFont.body(12, weight: .semibold))
            .foregroundStyle(.keptPurpleDeep)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.keptPurpleSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                price: storeKit.priceText,
                priceSuffix: "/mo",
                features: [("✓", "**Unlimited** habits"), ("✓", "**Unlimited** private locks"), ("✓", "Multiple circles"), ("✓", "Streak insights")],
                featured: true
            )
        }
    }

    private func planCard(plan: Plan, name: String, price: String, priceSuffix: String? = nil, features: [(String, String)], featured: Bool) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            guard !storeKit.isSubscribed else { return }
            selectedPlan = plan
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
                    isPurchasing = true
                    await storeKit.purchaseKeptPlus()
                    isPurchasing = false
                }
            } label: {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue (\(storeKit.priceText)/mo)")
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
             : "Billed through the App Store. Cancel anytime in Settings.")
            .font(KeptFont.body(11, weight: .medium))
            .foregroundStyle(.keptInkSoft)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }
}
