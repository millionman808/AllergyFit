import Foundation
import RevenueCat

/// Wraps RevenueCat: configuration, offerings, purchase/restore, and the
/// Premium entitlement state. During beta (no key configured) everything is
/// treated as unlocked so no feature is blocked before billing goes live.
@MainActor
final class PurchasesManager: ObservableObject {
    static let shared = PurchasesManager()

    @Published var isPremium = false
    @Published var packages: [Package] = []
    @Published var isLoadingOfferings = false
    @Published var purchaseError: String?

    /// True when RevenueCat is wired up with a real key.
    var isConfigured: Bool { !Config.revenueCatKey.isEmpty }

    /// Gate features on this. Beta: unlocked until billing is configured.
    var hasPremiumAccess: Bool { !isConfigured || isPremium }

    private var started = false

    func start() {
        guard !started, isConfigured else { return }
        started = true
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Config.revenueCatKey)
        Task { await refreshCustomerInfo() }
        Task { await loadOfferings() }
        // Live entitlement updates (e.g. renewals, family sharing).
        Task {
            for await info in Purchases.shared.customerInfoStream {
                isPremium = info.entitlements[Config.premiumEntitlement]?.isActive == true
            }
        }
    }

    /// Tie purchases to the signed-in Supabase user so they follow across devices.
    func identify(userId: String) async {
        guard isConfigured else { return }
        _ = try? await Purchases.shared.logIn(userId)
        await refreshCustomerInfo()
    }

    func signOut() async {
        guard isConfigured else { return }
        _ = try? await Purchases.shared.logOut()
        isPremium = false
    }

    func refreshCustomerInfo() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            isPremium = info.entitlements[Config.premiumEntitlement]?.isActive == true
        } catch {
            print("customerInfo failed: \(error)")
        }
    }

    func loadOfferings() async {
        guard isConfigured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            packages = offerings.current?.availablePackages ?? []
        } catch {
            print("offerings failed: \(error)")
        }
    }

    func purchase(_ package: Package) async {
        purchaseError = nil
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return }
            let entitlement = result.customerInfo.entitlements[Config.premiumEntitlement]
            isPremium = entitlement?.isActive == true
            guard isPremium else { return }

            // Tell the ad networks what just happened. A trial and a purchase
            // are reported as different events on purpose: a trial is worth $0
            // today, and the networks would otherwise learn to chase people
            // who never convert.
            let product = package.storeProduct
            if entitlement?.periodType == .trial {
                AdAttribution.logTrialStart(productID: product.productIdentifier)
            } else {
                AdAttribution.logPurchase(
                    amount: NSDecimalNumber(decimal: product.price).doubleValue,
                    currency: product.currencyCode ?? "USD",
                    productID: product.productIdentifier)
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        purchaseError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            isPremium = info.entitlements[Config.premiumEntitlement]?.isActive == true
            if !isPremium { purchaseError = "No previous purchases found to restore." }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}
