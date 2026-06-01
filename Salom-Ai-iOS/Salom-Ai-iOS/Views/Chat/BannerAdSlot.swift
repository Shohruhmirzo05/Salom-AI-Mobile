//
//  BannerAdSlot.swift
//  Salom-Ai-iOS
//
//  A small, premium AdMob banner shown ONLY to free users. Designed to feel
//  like part of the UI: a subtle rounded card with a quiet "Reklama" label,
//  reserved height (no layout jump), and an adaptive banner sized to the
//  screen. Hidden entirely for Pro users or when ads are disabled.
//

import SwiftUI
import GoogleMobileAds

// Google's official test banner unit — used until a real banner unit id is
// configured via /ads/config (ADMOB_IOS_BANNER_UNIT_ID).
private let kTestBannerUnitID = "ca-app-pub-3940256099942544/2934735716"

// MARK: - SwiftUI wrapper around GoogleMobileAds BannerView

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = adUnitID
        banner.rootViewController = RewardedAdManager.rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}

// MARK: - Premium, free-users-only banner slot

struct BannerAdSlot: View {
    @ObservedObject private var subs = SubscriptionManager.shared

    @State private var enabled = false
    @State private var unitID: String?

    private var resolvedUnitID: String { unitID ?? kTestBannerUnitID }

    var body: some View {
        Group {
            if enabled && !subs.isPro {
                VStack(spacing: 4) {
                    Text("Reklama")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(.white.opacity(0.28))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    BannerAdView(adUnitID: resolvedUnitID,
                                 width: UIScreen.main.bounds.width - 32)
                        .frame(height: 52)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .transition(.opacity)
            }
        }
        .task { await loadConfig() }
    }

    private func loadConfig() async {
        let url = APIClient.shared.baseURL.appendingPathComponent("ads/config")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "platform", value: "ios")]
        guard let finalURL = comps?.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: finalURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            await MainActor.run {
                self.enabled = (json?["enabled"] as? Bool) ?? false
                self.unitID = json?["admob_banner_unit_id"] as? String
            }
        } catch {
            // Leave disabled on failure — never show a broken slot.
        }
    }
}
