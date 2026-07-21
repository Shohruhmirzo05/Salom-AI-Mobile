//
//  ContentView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding)
    private var hasCompletedOnboarding: Bool = false
    
    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"
    
    @StateObject private var session = SessionManager.shared
    @State private var showSplash: Bool = true
    // Observe the payment-abandon survey flag (set after a non-paid checkout return).
    @ObservedObject private var subs = SubscriptionManager.shared
    @ObservedObject private var deepLinks = AppDeepLinkRouter.shared
#if DEBUG
    @State private var qaPaywallContext: PaywallContextID?
#endif

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()
            if showSplash {
                SplashView(isActive: $showSplash)
                    .transition(.opacity)
            } else if session.contentType == .onboarding || !hasCompletedOnboarding {
                OnboardingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if session.contentType == .login {
                AuthView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ChatContainerView()
                    .transition(.opacity)
                    .featureTipToast(isPro: subs.isPro)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: session.contentType)
        .onAppear {
            session.bootstrap(hasCompletedOnboarding: hasCompletedOnboarding)
            Analytics.shared.track("feature_opened", ["feature": "ios_app"])
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let marker = arguments.firstIndex(of: "-SALOM_QA_PAYWALL"),
               arguments.indices.contains(marker + 1) {
                qaPaywallContext = PaywallContextID(rawValue: arguments[marker + 1])
            }
#endif
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallSheet(context: .onboardingPersona, source: "ios_first_value")
        }
        .fullScreenCover(item: paywallDeepLinkBinding) { request in
            PaywallSheet(context: request.context, source: request.source)
        }
#if DEBUG
        .fullScreenCover(item: $qaPaywallContext) { context in
            PaywallSheet(context: context, source: "ios_debug_visual_qa")
        }
#endif
        .fullScreenCover(item: $winBackOffer) { offer in
            WinBackOfferSheet(offer: offer)
        }
        .sheet(isPresented: paymentSurveyBinding) {
            // "Why didn't you pay?" after a returned-but-not-paid checkout.
            WhyNotPaySurvey(
                onPick: { reason in
                    Task { await SubscriptionManager.shared.submitCancelSurvey(reason: reason) }
                    subs.showPaymentSurvey = false
                },
                onSkip: { subs.showPaymentSurvey = false }
            )
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showValueShowcase) {
            // "What can you do with Salom AI?" — first-run value showcase.
            ValueShowcaseSheet(onSeePro: { showPaywall = true })
                .presentationDetents([.large])
        }
        .onReceive(NotificationCenter.default.publisher(for: .showValueShowcase)) { _ in
            showValueShowcase = true
        }
        .onChange(of: showSplash) { _, isSplashActive in
            if !isSplashActive {
                print("DEBUG: Splash finished. Checking paywall.")
                checkAndShowPaywall()
            }
        }
        .onChange(of: session.contentType) { _, newValue in
            if newValue == .main && !showSplash {
                 checkAndShowPaywall()
                 // Push onboarding persona answers now that we're logged in.
                 PersonaStore.syncIfPending()
            } else if newValue != .main {
                // A payment prompt must never leak across logout/auth/onboarding.
                subs.resetPaymentRecovery()
            }
        }
    }

    private var paymentSurveyBinding: Binding<Bool> {
        Binding(
            get: {
                session.contentType == .main
                    && TokenStore.shared.accessToken != nil
                    && subs.showPaymentSurvey
            },
            set: { subs.showPaymentSurvey = $0 }
        )
    }

    private var paywallDeepLinkBinding: Binding<PaywallDeepLinkRequest?> {
        Binding(
            get: {
                session.contentType == .main && TokenStore.shared.accessToken != nil
                    ? deepLinks.paywallRequest
                    : nil
            },
            set: { deepLinks.paywallRequest = $0 }
        )
    }
    
    @State private var showPaywall = false
    @State private var hasShownPaywall = false
    @State private var winBackOffer: RecoveryOffer?
    @AppStorage("winback_last_shown_day") private var winBackLastShownDay: String = ""
    @AppStorage("organic_paywall_last_shown_day") private var organicPaywallLastShownDay: String = ""
    // First-run value showcase ("what can you do") — shown once, before any paywall.
    @AppStorage("value_shown_v1") private var valueShown: Bool = false
    @State private var showValueShowcase = false

    private func checkAndShowPaywall() {
        guard !hasShownPaywall else { return }
        guard !showSplash else { return }
        guard session.contentType == .main else { return }

        Task {
            // Always await a fresh subscription check before deciding.
            // During the splash path this is a no-op (data already loaded).
            // After a fresh login the subscription check hasn't completed yet,
            // so we must wait here to avoid a false-negative isPro = false.
            await SubscriptionManager.shared.checkSubscriptionStatus()

            let isPro = SubscriptionManager.shared.isPro

            await MainActor.run {
                hasShownPaywall = true  // mark regardless, so we never re-check
            }

            guard !isPro else { return }

            // First-ever open → show the value showcase (once) INSTEAD of the
            // paywall, so a brand-new user learns the breadth before being sold.
            // Its "See Pro" button opens the paywall on demand.
            if !valueShown {
                await MainActor.run {
                    valueShown = true
                    showValueShowcase = true
                }
                return
            }

            // ONE decision: win-back (for abandoned-payment users, once/day) takes
            // precedence; otherwise the generic paywall. Never both → no flash.
            let today = Self.dayKey()
            if winBackLastShownDay != today,
               let resp = await SubscriptionManager.shared.fetchRecoveryOffer(),
               resp.eligible, let best = resp.offers?.first {
                await MainActor.run { winBackLastShownDay = today }
                try? await Task.sleep(nanoseconds: 400_000_000)
                await MainActor.run { winBackOffer = best }
            } else if Self.daysSince(organicPaywallLastShownDay) >= 7 {
                await MainActor.run { organicPaywallLastShownDay = today }
                try? await Task.sleep(nanoseconds: 400_000_000)
                await MainActor.run { showPaywall = true }
            }
        }
    }

    private static func dayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func daysSince(_ key: String) -> Int {
        guard !key.isEmpty else { return .max }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: key) else { return .max }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? .max
    }
}
