//
//  TokenStore.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 23/01/25.
//

import Foundation

final class TokenStore {
    static let shared = TokenStore()
    
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    var accessToken: String? {
        let token = defaults.string(forKey: AppStorageKeys.accessToken)
        if let t = token {
            print("🔑 Access Token: \(t)")
        }
        return token
    }
    
    var refreshToken: String? {
        defaults.string(forKey: AppStorageKeys.refreshToken)
    }
    
    func save(accessToken: String, refreshToken: String) {
        defaults.set(accessToken, forKey: AppStorageKeys.accessToken)
        defaults.set(refreshToken, forKey: AppStorageKeys.refreshToken)
    }
    
    func updateAccessToken(_ token: String) {
        defaults.set(token, forKey: AppStorageKeys.accessToken)
    }
    
    func clear() {
        defaults.removeObject(forKey: AppStorageKeys.accessToken)
        defaults.removeObject(forKey: AppStorageKeys.refreshToken)
    }
}
