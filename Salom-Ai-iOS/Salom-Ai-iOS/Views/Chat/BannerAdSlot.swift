//
//  BannerAdSlot.swift
//  Salom-Ai-iOS
//
//  A small, premium AdMob banner shown ONLY to free users. Subtle rounded
//  card with a quiet "Reklama" label, reserved height (no layout jump), and an
//  adaptive banner sized to the screen. Hidden for Pro users.
//

import SwiftUI
import GoogleMobileAds

// Production banner unit (Salom AI), overridable via /ads/config.
// NOTE: never ship Google's test banner unit in a released build.
private let kDefaultBannerUnitID = "ca-app-pub-3378454853146779/5712979370"

// MARK: - SwiftUI wrapper around GoogleMobileAds BannerView

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = adUnitID
        banner.rootViewController = RewardedAdManager.rootViewController
        banner.delegate = context.coordinator
        print("🪧 Banner loading unit=\(adUnitID) width=\(width)")
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("🪧 ✅ Banner received ad")
        }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("🪧 ❌ Banner failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Premium, free-users-only banner slot

struct BannerAdSlot: View {
    @ObservedObject private var subs = SubscriptionManager.shared

    // Optimistic: render for free users immediately; only the unit id comes
    // from the backend (with a test fallback). ADS_ENABLED defaults true.
    @State private var unitID: String?
    @State private var showPaywall = false

    private var resolvedUnitID: String { unitID ?? kDefaultBannerUnitID }

    var body: some View {
        Group {
            if !subs.isPro {
                VStack(spacing: 4) {
                    HStack {
                        Text("Reklama")
                            .font(.system(size: 9, weight: .medium))
                            .tracking(0.5)
                            .foregroundColor(.white.opacity(0.28))
                        Spacer()
                        Button {
                            HapticManager.shared.fire(.lightImpact)
                            showPaywall = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

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
            }
        }
        .task { await loadConfig() }
        .onAppear { print("🪧 BannerAdSlot appear — isPro=\(subs.isPro)") }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet() }
    }

    private func loadConfig() async {
        let url = APIClient.shared.baseURL.appendingPathComponent("ads/config")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "platform", value: "ios")]
        guard let finalURL = comps?.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: finalURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let id = json?["admob_banner_unit_id"] as? String
            print("🪧 config banner unit=\(id ?? "nil")")
            await MainActor.run { self.unitID = id }
        } catch {
            print("🪧 config fetch failed: \(error.localizedDescription)")
        }
    }
}
