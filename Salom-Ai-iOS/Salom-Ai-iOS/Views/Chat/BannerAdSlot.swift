//
//  BannerAdSlot.swift
//  Salom-Ai-iOS
//
//  Premium "Reklama" slot shown ONLY to free users. It is an auto-rotating
//  2-card carousel:
//    • Card 1 — our own HOUSE ad (Fera Tech), always present.
//    • Card 2 — an AdMob adaptive banner; if AdMob has no fill (common in UZ),
//               this card falls back to a second house-ad variant so the slot
//               is never empty AND AdMob still gets a real frame to load into.
//  Hidden entirely for Pro users.
//

import SwiftUI
import GoogleMobileAds
import Combine

// Production banner unit (Salom AI), overridable via /ads/config.
// NOTE: never ship Google's test banner unit in a released build.
private let kDefaultBannerUnitID = "ca-app-pub-3378454853146779/5712979370"

// House-ad destination (our own business promo, shown as the AdMob backup).
private let kHouseAdURL = URL(string: "https://fera-tech.com/uz")!

private let kSlotHeight: CGFloat = 76

// MARK: - SwiftUI wrapper around GoogleMobileAds BannerView

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat
    /// Reports fill result up to the slot so it can swap in the house-ad backup.
    var onResult: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = adUnitID
        banner.rootViewController = RewardedAdManager.rootViewController
        banner.delegate = context.coordinator
        print("🪧 Banner loading unit=\(adUnitID) width=\(width)")
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        context.coordinator.onResult = onResult
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var onResult: (Bool) -> Void
        init(onResult: @escaping (Bool) -> Void) { self.onResult = onResult }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("🪧 ✅ Banner received ad")
            onResult(true)
        }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            // No-fill (code 3) is normal, especially in UZ — fall back to house ad.
            print("🪧 ❌ Banner failed: \(error.localizedDescription)")
            onResult(false)
        }
    }
}

// MARK: - House ad (our own promo, AdMob backup)

private struct HouseAdCard: View {
    /// Two slightly different angles so the rotating pair never looks identical.
    enum Variant { case appsAndSites, freeConsult }
    let variant: Variant
    let onTap: () -> Void

    private var headline: String {
        switch variant {
        case .appsAndSites: return "Biznesingiz uchun ilova yoki sayt kerakmi?"
        case .freeConsult:  return "Mobil ilova va veb-sayt — bepul konsultatsiya"
        }
    }
    private var subline: String {
        switch variant {
        case .appsAndSites: return "Fera Tech — professional yechim"
        case .freeConsult:  return "Fera Tech jamoasi siz uchun"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                leadingArt
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subline)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text("Batafsil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [Color(hex: "#1ED6FF"), Color(hex: "#7C3AED")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    )
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Real image if "fera-ad" is in the asset catalog; otherwise a clean
    // gradient tile with a device glyph — swap in the asset later, zero code.
    @ViewBuilder private var leadingArt: some View {
        if let ui = UIImage(named: "fera-ad") {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#1ED6FF"), Color(hex: "#7C3AED")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Premium, free-users-only banner slot (carousel)

struct BannerAdSlot: View {
    @ObservedObject private var subs = SubscriptionManager.shared
    @Environment(\.openURL) private var openURL

    @State private var unitID: String?
    @State private var showPaywall = false
    /// Whether AdMob actually returned an ad. When false, card 2 shows a house ad.
    @State private var adFilled = false
    /// Carousel page (0 = house ad, 1 = AdMob-or-house).
    @State private var page = 0

    // Rotate every 3s.
    private let rotation = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

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

                    carousel
                        .frame(height: kSlotHeight)
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
        .onReceive(rotation) { _ in
            withAnimation(.easeInOut(duration: 0.5)) { page = (page + 1) % 2 }
        }
        .onAppear { print("🪧 BannerAdSlot appear — isPro=\(subs.isPro)") }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet() }
    }

    @ViewBuilder private var carousel: some View {
        TabView(selection: $page) {
            HouseAdCard(variant: .appsAndSites, onTap: openHouseAd)
                .tag(0)

            // Card 2: AdMob always mounted (so it can load); the house-ad backup
            // sits ON TOP and is removed only once a real ad fills.
            ZStack {
                BannerAdView(adUnitID: resolvedUnitID,
                             width: UIScreen.main.bounds.width - 32,
                             onResult: { ok in
                                 withAnimation(.easeInOut(duration: 0.25)) { adFilled = ok }
                             })
                if !adFilled {
                    HouseAdCard(variant: .freeConsult, onTap: openHouseAd)
                }
            }
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func openHouseAd() {
        HapticManager.shared.fire(.lightImpact)
        Analytics.shared.track("house_ad_clicked", ["dest": "fera-tech"])
        openURL(kHouseAdURL)
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
