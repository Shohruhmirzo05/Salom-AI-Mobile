//
//  ReviewManager.swift
//  Salom-Ai-iOS
//
//  Created by Salom AI on 30/11/25.
//

import StoreKit
internal import UIKit

class ReviewManager {
    static let shared = ReviewManager()

    private let defaults = UserDefaults.standard
    private let positiveFeedbackCountKey = "review_positive_feedback_count"
    private let lastReviewRequestVersionKey = "last_review_request_version"
    private let firstUseDateKey = "review_first_use_date"
    private let pendingReviewKey = "review_pending_after_success"

    // Ask only after the user explicitly says an answer was useful. Two positive
    // ratings avoids turning one accidental tap into a system prompt, while the
    // seven-day age gate keeps first-session users focused on value.
    private let positiveFeedbackThreshold = 2
    private let minimumAccountAgeDays = 7
    
    private init() {}
    
    func recordPositiveFeedback() {
        if defaults.object(forKey: firstUseDateKey) == nil {
            defaults.set(Date(), forKey: firstUseDateKey)
        }
        let count = defaults.integer(forKey: positiveFeedbackCountKey) + 1
        defaults.set(count, forKey: positiveFeedbackCountKey)

        guard count >= positiveFeedbackThreshold, isPastAgeGate, !requestedForCurrentVersion else { return }
        // Do not open StoreKit directly from the thumbs-up tap. Apple recommends
        // asking at a later natural completion point, not as a button side effect.
        defaults.set(true, forKey: pendingReviewKey)
    }

    /// Call after a later task completes successfully. The small delay lets the
    /// answer settle before StoreKit decides whether to show its system sheet.
    func considerRequestAfterCompletedTask() {
        guard defaults.bool(forKey: pendingReviewKey), !requestedForCurrentVersion else { return }
        defaults.set(false, forKey: pendingReviewKey)
        defaults.set(0, forKey: positiveFeedbackCountKey)
        defaults.set(currentVersion, forKey: lastReviewRequestVersionKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.requestReview() }
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    private var requestedForCurrentVersion: Bool {
        defaults.string(forKey: lastReviewRequestVersionKey) == currentVersion
    }

    private var isPastAgeGate: Bool {
        guard let firstUse = defaults.object(forKey: firstUseDateKey) as? Date else { return false }
        return Date().timeIntervalSince(firstUse) >= Double(minimumAccountAgeDays) * 86_400
    }

    private func requestReview() {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
