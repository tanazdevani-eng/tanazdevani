import Foundation
import StoreKit

/// Owns the Kept+ auto-renewable subscription end to end: loading both the monthly and
/// yearly products, purchasing, restoring, and deciding entitlement from
/// `Transaction.currentEntitlements` (Apple's recommended on-device source of truth — no
/// server round trip needed to know whether someone is subscribed). Apple requires
/// StoreKit for all digital subscriptions; custom payment forms are not allowed and will
/// get the app rejected.
@MainActor
final class StoreKitManager: ObservableObject {
    static let monthlyProductID = "com.kept.app.keptplus.monthly"
    static let yearlyProductID = "com.kept.app.keptplus.yearly"

    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    /// Which product ID is actually entitled right now, if any — since monthly and yearly
    /// share one subscription group, at most one of them is ever active at a time.
    @Published private(set) var activeProductID: String?
    @Published private(set) var isLoadingProducts = false
    @Published var lastError: String?

    var isSubscribed: Bool { activeProductID != nil }

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: [Self.monthlyProductID, Self.yearlyProductID])
            monthlyProduct = products.first { $0.id == Self.monthlyProductID }
            yearlyProduct = products.first { $0.id == Self.yearlyProductID }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Kicks off the native App Store purchase sheet. Never build a custom "Continue"
    /// button that charges a card directly — that's an instant App Review rejection.
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// "Restore purchases" — required by App Review for any app with paid content, so a
    /// reinstall or new device can recover an existing subscription without repurchasing.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active: String?
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.monthlyProductID || transaction.productID == Self.yearlyProductID {
                active = transaction.productID
            }
        }
        activeProductID = active
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? self.checkVerified(update) {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "Apple could not verify this transaction." }
    }

    var monthlyPriceText: String {
        monthlyProduct?.displayPrice ?? "$\(Plan.keptPlusMonthlyPrice)"
    }

    var yearlyPriceText: String {
        yearlyProduct?.displayPrice ?? "$\(Plan.keptPlusYearlyPrice)"
    }
}
