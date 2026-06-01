//
//  RewardedAdManager.swift
//  Salom-Ai-iOS
//
//  Rewarded ads → +1 message when a plan limit is hit.
//
//  REQUIRES the Google Mobile Ads SDK (v12+) added via Swift Package Manager:
//    File ▸ Add Packages… ▸ https://github.com/googleads/swift-package-manager-google-mobile-ads
//
//  The reward is granted on the BACKEND via AdMob Server-Side Verification
//  (SSV). We attach the user's id as `customData`; Google calls our SSV URL
//  (/ads/reward/admob-ssv) which verifies the signature and credits +1.
//  The client never grants the reward itself — it only refreshes usage after
//  the ad finishes.
//
//  AdMob console setup (one-time):
//    Ad unit ▸ Server-side verification ▸ URL =
//      https://api.salom-ai.uz/ads/reward/admob-ssv
//

import Foundation
import SwiftUI
import GoogleMobileAds
import Combine

@MainActor
final class RewardedAdManager: NSObject, ObservableObject {
    static let shared = RewardedAdManager()

    /// Default test unit — replace via /ads/config or Constants for production.
    /// Google's official rewarded test unit id:
    private static let testUnitID = "ca-app-pub-3940256099942544/1712485313"

    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false

    private var rewardedAd: RewardedAd?
    private var unitID: String = RewardedAdManager.testUnitID
    private var didEarnReward = false

    private override init() { super.init() }

    /// Call once at launch (after MobileAds start) and after each presentation.
    func configure(unitID: String?) {
        if let unitID, !unitID.isEmpty { self.unitID = unitID }
        load()
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        let request = Request()
        RewardedAd.load(with: unitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            Task { @MainActor in
                self.isLoading = false
                if let error {
                    print("⚠️ Rewarded ad failed to load: \(error.localizedDescription)")
                    self.isReady = false
                    return
                }
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isReady = true
            }
        }
    }

    /// Present the ad. `onClose(rewarded:)` fires when the ad is dismissed;
    /// `rewarded` is true if the user earned the reward (backend grants via SSV).
    func present(onClose: @escaping (_ rewarded: Bool) -> Void) {
        guard let ad = rewardedAd, let root = Self.rootViewController else {
            onClose(false)
            load()
            return
        }

        // Attach the user id so AdMob's SSV callback can credit the right user.
        if let userID = Self.currentUserID {
            let options = ServerSideVerificationOptions()
            // customRewardText → arrives as `custom_data` in the SSV callback.
            options.customRewardText = userID
            ad.serverSideVerificationOptions = options
        }

        didEarnReward = false
        self.onCloseHandler = onClose
        ad.present(from: root) { [weak self] in
            self?.didEarnReward = true
        }
    }

    private var onCloseHandler: ((Bool) -> Void)?

    // MARK: - Helpers

    /// Decode the `sub` (user id) claim from the JWT access token.
    static var currentUserID: String? {
        guard let token = TokenStore.shared.accessToken else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let sub = json["sub"] as? String { return sub }
        if let sub = json["sub"] as? Int { return String(sub) }
        return nil
    }

    /// Fetch the production rewarded ad-unit id from the backend (/ads/config).
    /// Returns nil if ads are disabled or no unit configured (keeps test unit).
    static func fetchRewardedUnitID() async -> String? {
        let url = APIClient.shared.baseURL.appendingPathComponent("ads/config")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "platform", value: "ios")]
        guard let finalURL = comps?.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: finalURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard json?["enabled"] as? Bool == true else { return nil }
            return json?["admob_rewarded_unit_id"] as? String
        } catch {
            return nil
        }
    }

    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

extension RewardedAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let rewarded = didEarnReward
        rewardedAd = nil
        isReady = false
        onCloseHandler?(rewarded)
        onCloseHandler = nil
        load() // preload the next one
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("⚠️ Rewarded ad failed to present: \(error.localizedDescription)")
        rewardedAd = nil
        isReady = false
        onCloseHandler?(false)
        onCloseHandler = nil
        load()
    }
}
