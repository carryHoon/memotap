//
//  ProStore.swift
//  Tapst (MemoTap)
//
//  MemoTap Pro plans + StoreKit 2 purchasing/entitlement.
//  Requires the products below to exist in App Store Connect (or the bundled
//  Products.storekit for local testing, attached via the scheme).
//

import Foundation
import StoreKit

enum ProPlan: String, CaseIterable, Identifiable {
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .monthly: return "com.carryHoon.Tapst.pro.monthly"
        case .yearly: return "com.carryHoon.Tapst.pro.yearly"
        case .lifetime: return "com.carryHoon.Tapst.pro.lifetime"
        }
    }

    var title: String {
        switch self {
        case .monthly: return String(localized: "월 구독")
        case .yearly: return String(localized: "연 구독")
        case .lifetime: return String(localized: "평생 이용")
        }
    }

    /// Fallback price shown before StoreKit products load.
    var fallbackPrice: String {
        switch self {
        case .monthly: return "₩1,100"
        case .yearly: return "₩9,900"
        case .lifetime: return "₩16,900"
        }
    }

    var note: String? {
        switch self {
        case .monthly: return nil
        case .yearly: return String(localized: "가장 인기 · 월 대비 약 25% 절약")
        case .lifetime: return String(localized: "한 번 결제로 평생")
        }
    }

    var isRecommended: Bool { self == .yearly }
}

@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    private(set) var isPro: Bool = TapstStorage.isPro
    private(set) var products: [Product] = []
    private(set) var purchasing = false

    private let ids = ProPlan.allCases.map(\.productID)
    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    func product(for plan: ProPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    /// Localized price from StoreKit, or the fallback if products aren't loaded.
    func displayPrice(for plan: ProPlan) -> String {
        product(for: plan)?.displayPrice ?? plan.fallbackPrice
    }

    func loadProducts() async {
        do { products = try await Product.products(for: ids) }
        catch { products = [] }
    }

    func purchase(_ plan: ProPlan) async {
        guard let product = product(for: plan) else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // Surface errors to the UI later if needed.
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    /// Recomputes entitlement from the user's current StoreKit entitlements.
    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               ids.contains(transaction.productID),
               transaction.revocationDate == nil {
                owned = true
            }
        }
        setEntitlement(owned)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }

    private func setEntitlement(_ value: Bool) {
        guard TapstStorage.isPro != value || isPro != value else { return }
        TapstStorage.isPro = value
        isPro = value
        Task { await TapstLiveActivity.refresh() }
    }

    #if DEBUG
    /// Toggle Pro without a purchase (local testing only).
    func debugSetPro(_ value: Bool) { setEntitlement(value) }
    #endif
}
