//
//  SubscriptionManager.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 28/01/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPro: Bool = false
    @Published var currentPlan: CurrentSubscriptionResponse?
    @Published var plans: [SubscriptionPlan] = []
    @Published var isLoading = false
    
    private init() {}
    
    /// Fetches the latest subscription status from the API
    func checkSubscriptionStatus() async {
        guard TokenStore.shared.accessToken != nil else {
            self.isPro = false
            return
        }
        
        do {
            let sub = try await APIClient.shared.request(.currentSubscription, decodeTo: CurrentSubscriptionResponse.self)
            self.currentPlan = sub
            
            // Logic to determine if user is Pro
            // Adapting logic: if active and plan is not free/basic, or specific "pro" code
            // Adjust based on your actual plan codes. Assuming 'pro' or any paid plan means isPro.
            if sub.active {
                // If you have a specific list of pro plans, check against them.
                // For now, if it's active and plan exists, we consider it valid.
                // You might want to filter out a "free" plan if that exists and returns active=true.
                if let code = sub.plan, code != "free" {
                    if !self.isPro { HapticManager.shared.fire(.success) } // Fire only on state change to Pro
                    self.isPro = true
                } else {
                    self.isPro = false
                }
            } else {
                self.isPro = false
            }
            
            print("💎 Subscription Status: \(self.isPro ? "PRO" : "FREE") (Plan: \(sub.plan ?? "none"))")
            
        } catch {
            print("❌ Failed to fetch subscription status: \(error)")
            // On error, we don't revoke access immediately unless we want strict checking.
            // But usually safe to keep previous state or default to false if critical.
        }
    }
    
    private var hasLoadedPlans = false
    
    /// Fetches available plans
    func fetchPlans(force: Bool = false) async {
        if hasLoadedPlans && !force { return }
        
        self.isLoading = true
        do {
            let plans = try await APIClient.shared.request(.listPlans, decodeTo: [SubscriptionPlan].self)
            self.plans = plans
            self.hasLoadedPlans = true
        } catch {
            print("❌ Failed to fetch plans: \(error)")
        }
        self.isLoading = false
    }
    
    /// Initiates subscription for a given plan
    /// Returns the payment URL if successful
    func subscribe(planCode: String) async -> URL? {
        do {
            let response = try await APIClient.shared.request(.subscribe(plan: planCode, provider: "click"), decodeTo: SubscribeResponse.self)
            
            if let urlString = response.checkoutUrl, let url = URL(string: urlString) {
                return url
            }
        } catch {
            print("❌ Subscribe failed: \(error)")
        }
        return nil
    }
}
