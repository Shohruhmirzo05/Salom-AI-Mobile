//
//  SessionManager.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 24/01/25.
//

import SwiftUI
import Combine

enum ContentType: String {
    case onboarding
    case login
    case main
}

@MainActor
final class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var contentType: ContentType {
        didSet {
            UserDefaults.standard.set(contentType.rawValue, forKey: AppStorageKeys.contentType)
        }
    }
    
    private init() {
        if let raw = UserDefaults.standard.string(forKey: AppStorageKeys.contentType),
           let stored = ContentType(rawValue: raw) {
            contentType = stored
        } else {
            contentType = .onboarding
        }
    }
    
    func bootstrap(hasCompletedOnboarding: Bool) {
        if TokenStore.shared.accessToken != nil {
            contentType = .main
            Task {
                try? await APIClient.shared.requestData(.updatePlatform(platform: "ios"))
                await SubscriptionManager.shared.checkSubscriptionStatus()
            }
        } else {
            // Repair stale state left by expired tokens or older builds. A user
            // who already completed onboarding should return to authentication,
            // not replay onboarding or enter an unauthenticated chat shell.
            contentType = hasCompletedOnboarding ? .login : .onboarding
        }
    }
    
    func setAuthenticated() {
        // A successful authentication callback is not a payment callback. Clear
        // any abandoned checkout left in this app process before entering main.
        SubscriptionManager.shared.resetPaymentRecovery()
        contentType = .main
        UserDefaults.standard.set(true, forKey: AppStorageKeys.isAuthenticated)
        
        Task {
            try? await APIClient.shared.requestData(.updatePlatform(platform: "ios"))
            await SubscriptionManager.shared.checkSubscriptionStatus()
        }
        // Register OneSignal push id with backend (fixes iOS notifications).
        PushManager.syncDevice()
    }
    
    func logout() {
        SubscriptionManager.shared.resetPaymentRecovery()
        TokenStore.shared.clear()
        contentType = .login
        UserDefaults.standard.set(false, forKey: AppStorageKeys.isAuthenticated)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.displayName)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.userEmail)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.phoneNumber)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.avatarUrl)
    }
}
