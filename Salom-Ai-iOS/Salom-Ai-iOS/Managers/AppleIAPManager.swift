import Foundation
import StoreKit
import Combine

/// StoreKit 2 purchase coordinator. The App Store supplies localized prices and
/// signs every transaction; the backend verifies that signature before access
/// is granted or the transaction is finished.
@MainActor
final class AppleIAPManager: ObservableObject {
    static let shared = AppleIAPManager()

    @Published private(set) var productsByPlan: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private var config: IOSBillingConfig?
    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = observeTransactions()
    }

    deinit { updateTask?.cancel() }

    func configure(_ config: IOSBillingConfig) async {
        let changed = self.config?.mode != config.mode
            || self.config?.productIds != config.productIds
            || self.config?.appAccountToken != config.appAccountToken
        self.config = config
        guard config.mode == .appleIAP else {
            productsByPlan = [:]
            return
        }
        guard changed || productsByPlan.isEmpty else { return }
        await loadProducts()
        await syncCurrentEntitlements()
    }

    func displayPrice(for planCode: String) -> String? {
        productsByPlan[planCode]?.displayPrice
    }

    func purchase(planCode: String) async -> Bool {
        errorMessage = nil
        guard let config, config.mode == .appleIAP,
              let product = productsByPlan[planCode],
              let accountToken = UUID(uuidString: config.appAccountToken) else {
            errorMessage = String.appLocalized("App Store mahsuloti yuklanmadi. Qayta urinib ko'ring.")
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase(options: [.appAccountToken(accountToken)])
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = String.appLocalized("Xaridni tasdiqlab bo'lmadi.")
                    return false
                }
                return await submit(verification.jwsRepresentation, transaction: transaction, planCode: planCode)
            case .pending:
                errorMessage = String.appLocalized("Xarid tasdiqlanishi kutilmoqda.")
                return false
            case .userCancelled:
                return false
            @unknown default:
                errorMessage = String.appLocalized("Xaridni yakunlab bo'lmadi.")
                return false
            }
        } catch {
            errorMessage = localizedPurchaseError(error)
            return false
        }
    }

    func restorePurchases() async -> Bool {
        errorMessage = nil
        do {
            try await AppStore.sync()
            await syncCurrentEntitlements()
            await SubscriptionManager.shared.checkSubscriptionStatus()
            return SubscriptionManager.shared.isPro
        } catch {
            errorMessage = localizedPurchaseError(error)
            return false
        }
    }

    private func loadProducts() async {
        guard let config else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: Array(Set(config.productIds.values)))
            let byID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            productsByPlan = config.productIds.reduce(into: [:]) { result, entry in
                if let product = byID[entry.value] { result[entry.key] = product }
            }
            if productsByPlan.isEmpty {
                errorMessage = String.appLocalized("App Store mahsulotlari hozircha mavjud emas.")
            }
        } catch {
            errorMessage = localizedPurchaseError(error)
        }
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await verification in Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                guard case .verified(let transaction) = verification else { continue }
                guard let planCode = self.planCode(forProductID: transaction.productID) else { continue }
                _ = await self.submit(verification.jwsRepresentation, transaction: transaction, planCode: planCode)
            }
        }
    }

    private func syncCurrentEntitlements() async {
        guard config?.mode == .appleIAP else { return }
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification,
                  let planCode = planCode(forProductID: transaction.productID) else { continue }
            _ = await submit(verification.jwsRepresentation, transaction: transaction, planCode: planCode)
        }
    }

    private func planCode(forProductID id: String) -> String? {
        config?.productIds.first(where: { $0.value == id })?.key
    }

    private func submit(_ jws: String, transaction: Transaction, planCode: String) async -> Bool {
        do {
            let response = try await APIClient.shared.request(
                .verifyAppleTransaction(signedTransaction: jws, planCode: planCode),
                decodeTo: ApplePurchaseVerificationResponse.self
            )
            guard response.ok, response.active else {
                errorMessage = String.appLocalized("Obuna faol emas.")
                return false
            }
            await transaction.finish()
            await SubscriptionManager.shared.checkSubscriptionStatus()
            Analytics.shared.track("payment_completed", [
                "status": "paid", "plan": planCode, "platform": "ios", "provider": "apple"
            ])
            return true
        } catch {
            errorMessage = localizedPurchaseError(error)
            return false
        }
    }

    private func localizedPurchaseError(_ error: Error) -> String {
        if let storeError = error as? StoreKitError {
            switch storeError {
            case .networkError:
                return String.appLocalized("Internet aloqasini tekshirib, qayta urinib ko'ring.")
            case .notAvailableInStorefront:
                return String.appLocalized("Bu obuna hududingizda mavjud emas.")
            default:
                break
            }
        }
        return String.appLocalized("App Store xaridida xatolik yuz berdi. Qayta urinib ko'ring.")
    }
}
