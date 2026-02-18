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
        }
    }
    
    func setAuthenticated() {
        contentType = .main
        UserDefaults.standard.set(true, forKey: AppStorageKeys.isAuthenticated)
        
        Task {
            try? await APIClient.shared.requestData(.updatePlatform(platform: "ios"))
            await SubscriptionManager.shared.checkSubscriptionStatus()
        }
    }
    
    func logout() {
        TokenStore.shared.clear()
        contentType = .onboarding
        UserDefaults.standard.set(false, forKey: AppStorageKeys.isAuthenticated)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.displayName)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.userEmail)
        UserDefaults.standard.removeObject(forKey: AppStorageKeys.phoneNumber)
    }
}
