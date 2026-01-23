//
//  HapticManager.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 20/11/25.
//

internal import UIKit

enum HapticFeedback {
    case lightImpact
    case mediumImpact
    case heavyImpact
    case success
    case warning
    case error
    case selection
}

final class HapticManager {
    static let shared = HapticManager()

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    func fire(_ feedback: HapticFeedback) {
        switch feedback {
        case .lightImpact:
            impact(style: .light)
        case .mediumImpact:
            impact(style: .medium)
        case .heavyImpact:
            impact(style: .heavy)
        case .success:
            notify(type: .success)
        case .warning:
            notify(type: .warning)
        case .error:
            notify(type: .error)
        case .selection:
            selection()
        }
    }

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func notify(type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(type)
    }

    private func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}
