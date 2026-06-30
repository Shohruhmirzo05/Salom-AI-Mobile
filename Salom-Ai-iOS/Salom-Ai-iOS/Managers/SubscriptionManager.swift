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
    @Published var currentPlan: CurrentSubscriptionFull?
    @Published var plans: [SubscriptionPlan] = []
    @Published var savedCards: [SavedCard] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private init() {}
    
    /// Fetches the latest subscription status from the API
    func checkSubscriptionStatus() async {
        guard TokenStore.shared.accessToken != nil else {
            self.isPro = false
            return
        }

        do {
            let sub = try await APIClient.shared.request(.currentSubscription, decodeTo: CurrentSubscriptionFull.self)
            self.currentPlan = sub

            if sub.active {
                if let code = sub.plan, code != "free" {
                    if !self.isPro { HapticManager.shared.fire(.success) }
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
    
    /// Initiates subscription with card tokenization flow.
    /// Returns true if the backend acknowledged the tokenize action.
    func subscribe(planCode: String) async -> Bool {
        do {
            // Request with click_token provider — backend returns {action: "tokenize", ...}
            let _ = try await APIClient.shared.requestData(.subscribe(plan: planCode, provider: "click_token"))
            return true
        } catch {
            print("❌ Subscribe failed: \(error)")
            return false
        }
    }

    /// Initiates a one-time Click payment. Returns a checkout URL the caller should
    /// open in Safari / SFSafariViewController. After the user returns to the app,
    /// `checkSubscriptionStatus()` runs automatically on scenePhase == .active.
    func subscribeOneTime(planCode: String) async -> String? {
        await subscribeCheckout(planCode: planCode, provider: "click")
    }

    /// Generic redirect-checkout init for any provider (click | payme). Returns the
    /// checkout URL the caller opens in Safari. After return, scenePhase .active
    /// re-checks subscription status.
    func subscribeCheckout(planCode: String, provider: String) async -> String? {
        do {
            let response = try await APIClient.shared.request(
                .subscribe(plan: planCode, provider: provider),
                decodeTo: SubscribeResponse.self
            )
            return response.checkoutUrl
        } catch {
            print("❌ \(provider) subscribe failed: \(error)")
            lastError = "\(error)"
            return nil
        }
    }

    // MARK: - Card Tokenization

    /// Step 1: Send card details to Click for tokenization
    func tokenizeCard(cardNumber: String, expireDate: String) async -> TokenizeRequestResponse? {
        lastError = nil
        do {
            let response = try await APIClient.shared.request(
                .tokenizeCardRequest(cardNumber: cardNumber, expireDate: expireDate),
                decodeTo: TokenizeRequestResponse.self
            )
            return response
        } catch let error as APIError {
            if case .server(_, let message) = error {
                lastError = message
            }
            print("❌ Tokenize card failed: \(error)")
            return nil
        } catch {
            print("❌ Tokenize card failed: \(error)")
            return nil
        }
    }

    /// Step 2: Verify SMS code, save card, charge first payment
    func verifySMS(requestId: String, smsCode: Int, planCode: String) async -> TokenizeVerifyResponse? {
        lastError = nil
        do {
            let response = try await APIClient.shared.request(
                .tokenizeCardVerify(requestId: requestId, smsCode: smsCode, planCode: planCode),
                decodeTo: TokenizeVerifyResponse.self
            )
            return response
        } catch let error as APIError {
            if case .server(_, let message) = error {
                lastError = message
            }
            print("❌ Verify SMS failed: \(error)")
            return nil
        } catch {
            print("❌ Verify SMS failed: \(error)")
            return nil
        }
    }

    // MARK: - Saved Cards

    func fetchSavedCards() async {
        do {
            let cards = try await APIClient.shared.request(.savedCards, decodeTo: [SavedCard].self)
            self.savedCards = cards
        } catch {
            print("❌ Failed to fetch saved cards: \(error)")
        }
    }

    func deleteCard(id: Int) async -> Bool {
        do {
            let _ = try await APIClient.shared.requestData(.deleteCard(id: id))
            savedCards.removeAll { $0.id == id }
            return true
        } catch {
            print("❌ Delete card failed: \(error)")
            return false
        }
    }

    // MARK: - Auto-Renew & Cancel

    func toggleAutoRenew(cardId: Int?, enabled: Bool) async -> Bool {
        do {
            let response = try await APIClient.shared.request(
                .autoRenew(cardId: cardId, enabled: enabled),
                decodeTo: AutoRenewResponse.self
            )
            // Refresh subscription status
            await checkSubscriptionStatus()
            return response.ok
        } catch {
            print("❌ Toggle auto-renew failed: \(error)")
            return false
        }
    }

    func cancelSubscription() async -> Bool {
        do {
            let response = try await APIClient.shared.request(
                .cancelSubscription,
                decodeTo: CancelSubscriptionResponse.self
            )
            await checkSubscriptionStatus()
            return response.ok
        } catch {
            print("❌ Cancel subscription failed: \(error)")
            return false
        }
    }

    // MARK: - Retention: cancel survey + win-back

    /// Record WHY the user is leaving / didn't pay. Feeds the admin "Nega to'lov
    /// qilishmadi?" breakdown. Also mirrors the web `cancel_survey` analytics event.
    @discardableResult
    func submitCancelSurvey(reason: String) async -> Bool {
        Analytics.shared.track("cancel_survey", ["reason": reason])
        do {
            let _ = try await APIClient.shared.requestData(.cancelSurvey(reason: reason))
            return true
        } catch {
            print("❌ Cancel survey failed: \(error)")
            return false
        }
    }

    /// Win-back: returns a discounted offer for users who abandoned a payment.
    /// `nil`/`eligible == false` means show normal pricing (no popup).
    func fetchRecoveryOffer() async -> RecoveryOfferResponse? {
        do {
            return try await APIClient.shared.request(.recoveryOffer, decodeTo: RecoveryOfferResponse.self)
        } catch {
            print("❌ Recovery offer fetch failed: \(error)")
            return nil
        }
    }
}
