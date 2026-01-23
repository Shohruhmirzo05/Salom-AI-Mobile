//
//  OAuthProvider.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 22/12/24.
//

import Foundation

enum OAuthProvider: String {
    case google
    case apple
    
    var displayName: String {
        switch self {
        case .google:
            return "Google"
        case .apple:
            return "Apple"
        }
    }
    
    var supabaseValue: String { rawValue }
}
