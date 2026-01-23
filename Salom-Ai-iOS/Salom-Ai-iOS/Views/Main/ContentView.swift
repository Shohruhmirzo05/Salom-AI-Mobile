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
    @State private var refreshID = UUID()

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
        .id(refreshID)
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: session.contentType)
        .onChange(of: languageCode) { _ in
            refreshID = UUID()
        }
        .onAppear {
            session.bootstrap(hasCompletedOnboarding: hasCompletedOnboarding)
        }
    }
}
