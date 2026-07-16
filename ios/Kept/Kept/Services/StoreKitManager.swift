import Foundation
import StoreKit

/// Owns the Kept+ auto-renewable subscription end to end: loading the product, purchasing,
/// restoring, and deciding entitlement from `Transaction.currentEntitlements` (Apple's
/// recommended on-device source of truth — no server round trip needed to know whether
/// someone is subscribed). Apple requires StoreKit for all digital subscriptions; custom
/// payment forms are not allowed and will get the app rejected.
@MainActor
final class StoreKitManager: ObservableObject {
    static let keptPlusProductID = "com.kept.app.keptplus.monthly"

    @Published private(set) var keptPlusProduct: Product?
    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoadingProducts = false
    @Published var lastError: String?

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
            let products = try await Product.products(for: [Self.keptPlusProductID])
            keptPlusProduct = products.first
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Kicks off the native App Store purchase sheet. Never build a custom "Continue"
    /// button that charges a card directly — that's an instant App Review rejection.
    func purchaseKeptPlus() async {
        guard let product = keptPlusProduct else {
            lastError = "Kept+ isn't available right now. Check your connection and try again."
            return
        }
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
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result), transaction.productID == Self.keptPlusProductID {
                subscribed = true
            }
        }
        isSubscribed = subscribed
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

    var priceText: String {
        keptPlusProduct?.displayPrice ?? "$\(Plan.keptPlusMonthlyPrice)"
    }
}
