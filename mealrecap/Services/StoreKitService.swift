import Foundation
import StoreKit

@MainActor
final class StoreKitService: ObservableObject {
    @Published var products: [Product] = []
    @Published var isPro = false
    @Published var purchaseError: String?
    @Published var isLoadingProducts = false

    private var updatesTask: Task<Void, Never>?

    enum ProductID {
        static let weekly = "com.sbj.mealrecap.pro.weekly"
        static let monthly = "com.sbj.mealrecap.pro.monthly"
        static let yearly = "com.sbj.mealrecap.pro.yearly"
        static let all = [weekly, monthly, yearly]
    }

    func configure() async {
        await loadProducts()
        await updateEntitlementState()
        updatesTask = Task { await observeTransactions() }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: ProductID.all).sorted { lhs, rhs in
                productSortRank(lhs.id) < productSortRank(rhs.id)
            }
            #if DEBUG
            if products.contains(where: { $0.id == ProductID.weekly }) == false {
                print("[StoreKit] Weekly product unavailable; paywall will omit weekly option.")
            }
            #endif
            purchaseError = nil
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateEntitlementState()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await updateEntitlementState()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func observeTransactions() async {
        for await update in Transaction.updates {
            do {
                let transaction = try checkVerified(update)
                await transaction.finish()
                await updateEntitlementState()
            } catch {
                await MainActor.run { self.purchaseError = error.localizedDescription }
            }
        }
    }

    private func updateEntitlementState() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            if ProductID.all.contains(transaction.productID) {
                active = true
            }
        }
        isPro = active
    }

    private func productSortRank(_ id: String) -> Int {
        if id == ProductID.yearly { return 0 }
        if id == ProductID.monthly { return 1 }
        if id == ProductID.weekly { return 2 }
        return 99
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "The transaction could not be verified." }
    }
}
