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
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: session.contentType)
        .onAppear {
            session.bootstrap(hasCompletedOnboarding: hasCompletedOnboarding)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallSheet()
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
            }
        }
    }
    
    @State private var showPaywall = false
    @State private var hasShownPaywall = false
    
    private func checkAndShowPaywall() {
        guard !hasShownPaywall else { return }
        guard !showSplash else { return }

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

            if !isPro {
                try? await Task.sleep(nanoseconds: 400_000_000)
                await MainActor.run {
                    showPaywall = true
                }
            }
        }
    }
}
