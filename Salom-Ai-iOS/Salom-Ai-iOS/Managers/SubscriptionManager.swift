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

    /// Root-level payment-result banner. Set by the deep-link / foreground funnel,
    /// observed by `ContentView.paymentToast(_:)`. Never set this directly from a
    /// view — go through `handlePaymentReturn` / `refreshAfterForeground`.
    @Published var paymentToast: PaymentToast?

    /// Root-level "why didn't you pay?" survey. Set true when a checkout is
    /// returned-from but NOT paid (failed / cancelled / abandoned). Observed by
    /// ContentView, which presents the WhyNotPaySurvey sheet.
    @Published var showPaymentSurvey = false

    // MARK: - Redirect-checkout tracking
    //
    // When we hand a user off to a Payme/Click redirect checkout we remember the
    // specific payment here. On return — via the `salomai://` deep link or the
    // scenePhase foreground fallback — we resolve exactly ONE confirmation toast,
    // driven by the AUTHORITATIVE per-payment status from the backend. We never
    // infer success from `isPro`: an already-subscribed user upgrading is pro both
    // before and after, so `isPro` says nothing about whether THIS payment landed.

    /// The transaction id of the checkout we opened; `nil` once resolved.
    private var pendingPaymentId: Int?
    /// The plan the pending checkout was for (surfaced in the toast).
    private var pendingCheckoutPlan: String?
    /// When the checkout was opened; a checkout the user silently abandoned can't
    /// fire a stale toast days later.
    private var pendingCheckoutAt: Date?
    /// Freshness window for a pending checkout.
    private let pendingCheckoutTTL: TimeInterval = 30 * 60
    /// Guards against overlapping backend status polls (deep link + foreground).
    private var isPollingPaymentStatus = false

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

    // MARK: - Payment-return funnel

    /// Called from the `salomai://payment/result?payment_id=…&status=…` deep link.
    /// The web result page only redirects here after polling the payment, so its
    /// `status` is trusted (a terminal value resolves the toast without a round-trip).
    func handlePaymentReturn(status: String?, paymentId: Int?) async {
        await resolvePayment(id: paymentId ?? pendingPaymentId, trustedStatus: status)
    }

    /// Called on scenePhase → .active. The fallback for when the deep link never
    /// fires (e.g. the user paid — or abandoned — in the Payme app and returned
    /// manually). Polls the real payment status; shows nothing until it's terminal.
    func refreshAfterForeground() async {
        guard TokenStore.shared.accessToken != nil else {
            resetPaymentRecovery()
            return
        }
        await checkSubscriptionStatus()
        guard pendingPaymentId != nil else { return }
        await resolvePayment(id: pendingPaymentId, trustedStatus: nil)
    }

    /// Resolves a pending checkout using the authoritative payment status.
    ///
    /// Fast path: a trusted terminal status from the deep link needs no network.
    /// Slow path: poll `GET /subscriptions/payments/{id}` (same source the web page
    /// uses). A non-terminal status (`pending`/`waiting_user`) shows NOTHING and
    /// leaves the checkout armed, so an abandoned payment never fakes a success.
    private func resolvePayment(id: Int?, trustedStatus: String?) async {
        guard let startedAt = pendingCheckoutAt else { return }            // nothing armed
        guard Date().timeIntervalSince(startedAt) < pendingCheckoutTTL else {
            clearPendingCheckout(); return                                 // window expired
        }

        // Fast path — trusted terminal status from the deep link, no round-trip.
        if let kind = PaymentToastKind(status: trustedStatus) {
            await finishPayment(kind)
            return
        }

        // Slow path — poll the backend for the REAL status. One resolver at a time.
        guard !isPollingPaymentStatus, let id else { return }
        isPollingPaymentStatus = true
        defer { isPollingPaymentStatus = false }

        // Immediate "checking…" feedback so the user never returns to silence.
        presentToast(.checking, plan: pendingCheckoutPlan)

        // Retry a few times: a just-paid order may take a few seconds for the
        // Payme/Click webhook to land. Abandoned orders stay 'pending'.
        for attempt in 0..<5 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 2_500_000_000) }
            // Bail if a peer (deep link) already resolved this checkout.
            guard pendingCheckoutAt != nil else { return }
            if let resp = try? await APIClient.shared.request(
                    .paymentStatus(id: id), decodeTo: PaymentStatusResponse.self),
               let kind = PaymentToastKind(status: resp.status) {
                await finishPayment(kind)
                return
            }
        }

        // Still not terminal after retries → treat as abandoned: show a pending
        // info toast and ask WHY they didn't pay. Keep the checkout armed so a
        // late webhook can still flip it to success on the next foreground.
        guard pendingCheckoutAt != nil else { return }
        presentToast(.pending, plan: pendingCheckoutPlan)
        showPaymentSurvey = true
    }

    /// Terminal resolution. Claims the pending checkout synchronously (clearing it
    /// before any `await`) so a racing deep-link + foreground pair yields exactly
    /// one toast, then refreshes the plan and presents.
    private func finishPayment(_ kind: PaymentToastKind) async {
        guard pendingCheckoutAt != nil else { return }  // already claimed by a peer
        let plan = pendingCheckoutPlan
        clearPendingCheckout()
        await checkSubscriptionStatus()
        presentToast(kind, plan: plan)
        // Not paid → ask why (failed / cancelled). Success never surveys.
        if kind != .success {
            showPaymentSurvey = true
        }
    }

    /// Marks that a redirect checkout was just opened.
    func markPendingCheckout(plan: String?, paymentId: Int?) {
        pendingPaymentId = paymentId
        pendingCheckoutPlan = plan
        pendingCheckoutAt = Date()
    }

    /// Discards UI and transaction state that belongs to an interrupted redirect
    /// checkout. Authentication has its own external-app/browser lifecycle; stale
    /// payment state must never be resumed when Google, Apple, or Telegram returns.
    func resetPaymentRecovery() {
        clearPendingCheckout()
        paymentToast = nil
        showPaymentSurvey = false
    }

    private func clearPendingCheckout() {
        pendingPaymentId = nil
        pendingCheckoutPlan = nil
        pendingCheckoutAt = nil
    }

    private func presentToast(_ kind: PaymentToastKind, plan: String?) {
        // Only terminal outcomes are a "completed" funnel event; skip checking/pending.
        if kind.isTerminal {
            Analytics.shared.track("payment_completed", [
                "status": kind == .success ? "paid" : (kind == .failed ? "failed" : "cancelled"),
                "plan": plan ?? currentPlan?.plan ?? "unknown",
                "platform": "ios",
            ])
        }
        // Ensure the top-most overlay window exists so the toast floats above any
        // open sheet / fullScreenCover, then publish it.
        ToastWindowController.shared.install()
        paymentToast = PaymentToast(kind, plan: plan)
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
            // Only arm the return funnel once we actually have a URL to open.
            if response.checkoutUrl != nil {
                markPendingCheckout(plan: planCode, paymentId: response.paymentId)
            }
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

    /// Manually retry a failed card payment with the same saved card. Returns
    /// (success, errorMessage). Reactivates the subscription on success.
    func retryPayment() async -> (Bool, String?) {
        do {
            let response = try await APIClient.shared.request(.retryPayment, decodeTo: RetryPaymentResponse.self)
            await checkSubscriptionStatus()
            return (response.ok, nil)
        } catch let APIError.server(_, message) {
            return (false, message)
        } catch {
            return (false, nil)
        }
    }

    // MARK: - Retention: cancel survey + win-back

    /// Record WHY the user is leaving / didn't pay. Feeds the admin "Nega to'lov
    /// qilishmadi?" breakdown. Also mirrors the web `cancel_survey` analytics event.
    @discardableResult
    func submitCancelSurvey(reason: String, paywallID: String? = nil) async -> Bool {
        if let paywallID { PaywallAttributionStore.shared.set(context: PaywallContextID(rawValue: paywallID) ?? .general, source: "ios") }
        Analytics.shared.track("cancel_survey", ["reason": reason, "paywall_id": paywallID ?? PaywallAttributionStore.shared.paywallID ?? "unknown"])
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
