//
//  SubscriptionStatus.swift
//  Palettes
//
//  Which plan the app is on, from StoreKit's current entitlements: Premium is
//  any active, verified entitlement to one of `productIDs`; everything else
//  is Free. Until the subscription products exist, everyone is on Free.
//

import Foundation
import StoreKit

enum AppPlan: String, CaseIterable, Identifiable {
    case free
    case premium

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: "Free"
        case .premium: "Premium"
        }
    }
}

@MainActor
final class SubscriptionStatus: ObservableObject {
    static let shared = SubscriptionStatus()

    // TODO(owner): the auto-renewable subscription product IDs from App Store
    // Connect (and the StoreKit configuration file) once Premium is set up.
    static let productIDs: Set<String> = []

    #if DEBUG
    /// Debug-only override from Settings: "" follows StoreKit, otherwise an
    /// `AppPlan` raw value.
    static let debugOverrideKey = "debugPlanOverride"
    #endif

    @Published private(set) var plan: AppPlan = .free

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Renewals, refunds and purchases on other devices arrive here.
        updatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        var isPremium = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                isPremium = true
            }
        }

        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: Self.debugOverrideKey),
           let override = AppPlan(rawValue: raw) {
            plan = override
            return
        }
        #endif

        plan = isPremium ? .premium : .free
    }
}
