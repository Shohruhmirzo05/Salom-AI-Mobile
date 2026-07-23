import SwiftUI

@MainActor
private enum ContextualAdImpressionRegistry {
    static var keys = Set<String>()

    static func record(_ key: String) -> Bool {
        keys.insert(key).inserted
    }
}

/// A deliberately quiet, clearly disclosed house recommendation attached to a
/// relevant assistant answer. Selection and frequency caps live on the backend;
/// this view only renders the trusted payload and records visibility/clicks.
struct ContextualSponsoredRecommendationView: View {
    let recommendation: SponsoredRecommendation
    let messageID: String
    let conversationID: Int?

    @Environment(\.openURL) private var openURL
    private var assetName: String {
        switch recommendation.product {
        case "bandmate": "bandmate-ad"
        case "business": "business-ad"
        case "fera": "fera-ad"
        default: "AppIcon"
        }
    }

    var body: some View {
        Button {
            guard let url = trustedURL else { return }
            HapticManager.shared.fire(.lightImpact)
            Analytics.shared.track("ad_click", analyticsProperties)
            openURL(url)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Rectangle()
                    .fill(SalomTheme.Colors.border)
                    .frame(height: 0.5)

                HStack(spacing: 9) {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 27, height: 27)
                        .padding(3)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(SalomTheme.Colors.border, lineWidth: 0.5)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.label.uppercased())
                            .font(.system(size: 8.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(SalomTheme.Colors.textTertiary)
                        Text(recommendation.headline)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Text(recommendation.description)
                            .font(.system(size: 10.5))
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.accentPrimary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(recommendation.label). \(recommendation.headline). \(recommendation.cta)")
        .onAppear {
            guard ContextualAdImpressionRegistry.record(impressionKey) else { return }
            Analytics.shared.track("ad_impression", analyticsProperties)
        }
    }

    private var trustedURL: URL? {
        guard let url = URL(string: recommendation.url),
              let host = url.host?.lowercased(),
              ["bandmate.uz", "business.salom-ai.uz", "fera-tech.com", "www.fera-tech.com"].contains(host)
        else { return nil }
        return url
    }

    private var impressionKey: String {
        "\(conversationID ?? 0):\(messageID):\(recommendation.product)"
    }

    private var analyticsProperties: [String: Any] {
        var properties: [String: Any] = [
            "product": recommendation.product,
            "surface": "ios_chat",
            "placement": "contextual_answer",
            "message_id": messageID,
        ]
        if let conversationID {
            properties["conversation_id"] = conversationID
        }
        return properties
    }
}
