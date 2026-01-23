//
//  AppStorageKeys.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import Foundation

enum AppStorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let isAuthenticated        = "isAuthenticated"
    // contentType replaces isAuthenticated; kept for backward compatibility.
    static let contentType            = "contentType"
    static let phoneNumber            = "phoneNumber"
    static let displayName            = "displayName"
    static let preferredLanguageCode  = "preferredLanguageCode"
    static let accessToken            = "accessToken"
    static let refreshToken           = "refreshToken"
}
