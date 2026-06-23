import Foundation
import StoreKit

enum MealRecapProductID {
    static let weekly = "com.denzeltinashe.mealrecap.pro.weekly"
    static let monthly = "com.denzeltinashe.mealrecap.pro.monthly"
    static let yearly = "com.denzeltinashe.mealrecap.pro.yearly"
    static let all = [weekly, monthly, yearly]
}

@MainActor
final class StoreKitService: ObservableObject {
    enum ProductID {
        static let weekly = MealRecapProductID.weekly
        static let monthly = MealRecapProductID.monthly
        static let yearly = MealRecapProductID.yearly
        static let all = MealRecapProductID.all
    }

    enum ProductLoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
        case failed
    }

    enum RestoreState: Equatable {
        case idle
        case restoring
        case restored
        case noActiveSubscription
        case failed
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var productLoadState: ProductLoadState = .idle
    @Published private(set) var restoreState: RestoreState = .idle
    @Published private(set) var purchasingProductID: String?
    @Published var purchaseError: String?

    var isLoadingProducts: Bool { productLoadState == .loading }

    private let productTimeoutSeconds: UInt64 = 12
    private let purchaseTimeoutSeconds: UInt64 = 45
    private let cachedEntitlementKey = "mealrecap.storekit.cachedProEntitlement.v1"
    private var updatesTask: Task<Void, Never>?

    deinit {
        updatesTask?.cancel()
    }

    func configure() async {
        isPro = UserDefaults.standard.bool(forKey: cachedEntitlementKey)
        updatesTask?.cancel()
        updatesTask = Task { await observeTransactions() }

        Task {
            await loadProducts()
            await refreshEntitlementFromStoreKit()
        }
    }

    func loadProducts() async {
        guard productLoadState != .loading else { return }
        productLoadState = .loading
        purchaseError = nil

        do {
            let fetched = try await withTimeout(seconds: productTimeoutSeconds) {
                try await Product.products(for: ProductID.all)
            }
            products = fetched.sorted { productSortRank($0.id) < productSortRank($1.id) }
            productLoadState = products.isEmpty ? .unavailable : .loaded
            if products.isEmpty {
                purchaseError = "Subscriptions are unavailable right now. Please try again."
            }
        } catch {
            products = []
            productLoadState = .failed
            purchaseError = "Subscriptions are unavailable right now. Please try again."
        }
    }

    func purchase(_ product: Product) async -> Bool {
        guard purchasingProductID == nil else { return false }
        purchasingProductID = product.id
        purchaseError = nil
        defer { purchasingProductID = nil }

        do {
            let result = try await withTimeout(seconds: purchaseTimeoutSeconds) {
                try await product.purchase()
            }
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                setCachedPro(true)
                await refreshEntitlementFromStoreKit()
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Purchase is pending approval. Check your Apple Account for updates."
                return false
            @unknown default:
                purchaseError = "Purchase couldn’t be completed. Try again."
                return false
            }
        } catch {
            purchaseError = "Purchase couldn’t be completed. Try again."
            return false
        }
    }

    @discardableResult
    func restore() async -> RestoreState {
        guard restoreState != .restoring else { return restoreState }
        restoreState = .restoring
        purchaseError = nil

        do {
            try await withTimeout(seconds: purchaseTimeoutSeconds) {
                try await AppStore.sync()
            }
            await refreshEntitlementFromStoreKit()
            restoreState = isPro ? .restored : .noActiveSubscription
        } catch {
            restoreState = .failed
            purchaseError = "Couldn’t restore purchases. Try again."
        }
        return restoreState
    }

    func refreshEntitlementFromStoreKit() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            if ProductID.all.contains(transaction.productID), transaction.revocationDate == nil {
                active = true
            }
        }
        if active || !UserDefaults.standard.bool(forKey: cachedEntitlementKey) {
            setCachedPro(active)
        } else {
            isPro = true
        }
    }

    private func observeTransactions() async {
        for await update in Transaction.updates {
            do {
                let transaction = try checkVerified(update)
                await transaction.finish()
                await refreshEntitlementFromStoreKit()
            } catch {
                purchaseError = "Couldn’t update purchase status right now."
            }
        }
    }

    private func setCachedPro(_ active: Bool) {
        isPro = active
        UserDefaults.standard.set(active, forKey: cachedEntitlementKey)
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

    private func withTimeout<T: Sendable>(seconds: UInt64, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw StoreError.timedOut
            }
            guard let result = try await group.next() else { throw StoreError.timedOut }
            group.cancelAll()
            return result
        }
    }

    enum StoreError: LocalizedError {
        case failedVerification
        case timedOut

        var errorDescription: String? {
            switch self {
            case .failedVerification, .timedOut:
                return "Purchase couldn’t be completed. Try again."
            }
        }
    }
}
