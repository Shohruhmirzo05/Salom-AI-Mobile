//
//  ReviewManager.swift
//  Salom-Ai-iOS
//
//  Created by Salom AI on 30/11/25.
//

import StoreKit
import SwiftUI
internal import UIKit

class ReviewManager {
    static let shared = ReviewManager()
    
    private let defaults = UserDefaults.standard
    private let actionCountKey = "review_action_count"
    private let lastReviewRequestVersionKey = "last_review_request_version"
    
    // Request review after every 5 meaningful interactions (as requested by user "every maybe couple of chats")
    // The user mentioned "every maybe couple of chats... like two, three, four messages". 
    // Let's set it to 5 to be safe but frequent enough.
    private let threshold = 5
    
    private init() {}
    
    func incrementActionCount() {
        let currentCount = defaults.integer(forKey: actionCountKey)
        let newCount = currentCount + 1
        defaults.set(newCount, forKey: actionCountKey)
        
        print("⭐️ [ReviewManager] Action count: \(newCount)/\(threshold)")
        
        if newCount >= threshold {
            requestReview()
            defaults.set(0, forKey: actionCountKey) // Reset count
        }
    }
    
    private func requestReview() {
        // Check if we already requested for this version (optional, but good practice to avoid spamming if OS doesn't filter)
        // However, StoreKit already handles rate limiting (3 times per year).
        // The user wants to "force" it (show custom alert first), so we will show our alert first.
        
        DispatchQueue.main.async {
            // Get the current window scene
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            
            // Show custom alert first
            self.showPreReviewAlert(in: scene)
        }
    }
    
    private func showPreReviewAlert(in scene: UIWindowScene) {
        let alert = UIAlertController(
            title: "Sizga Salom AI yoqyaptimi?".localizedString(),
            message: "Agar ilovadan foydalanish sizga yoqsa, iltimos, uni baholash uchun bir oz vaqt ajrating. Bu bizga uni yaxshilashga yordam beradi!".localizedString(),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(
            title: "5 yulduz qo'yish".localizedString(),
            style: .default,
            handler: { _ in
                SKStoreReviewController.requestReview(in: scene)
            }
        ))

        alert.addAction(UIAlertAction(
            title: "Hozir emas".localizedString(),
            style: .cancel,
            handler: nil
        ))

        if let rootVC = scene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(alert, animated: true)
        }
    }
}

extension String {
    func localizedString(identifier: String? = nil, table: String? = "Localizable") -> String {
        let userPreferredIdentifier = UserDefaults.standard.string(forKey: "app_language")
        let fallbackIdentifier = Bundle.main.preferredLocalizations.first ?? Locale.current.identifier
        let currentIdentifier = userPreferredIdentifier ?? fallbackIdentifier
        let currentLocale = Locale(identifier: identifier ?? currentIdentifier)
        guard let languageCode = currentLocale.language.languageCode?.identifier,
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return self
        }
        return NSLocalizedString(self, tableName: table, bundle: bundle, comment: "")
    }
}
