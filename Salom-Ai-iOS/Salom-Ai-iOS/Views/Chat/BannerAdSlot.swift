//
//  BannerAdSlot.swift
//  Salom-Ai-iOS
//
//  Premium "Reklama" slot shown ONLY to free users. An auto-rotating carousel of
//  our own HOUSE ads (Fera Tech, BandMate, Salom AI Biznes) plus an AdMob adaptive
//  banner as the last page. If AdMob has no fill (common in UZ), that page falls
//  back to a house ad so the slot is never empty. Hidden entirely for Pro users.
//
//  Clicks/impressions report to the same analytics schema as web/blog:
//    ad_impression / ad_click  with props { product, surface: "ios_chat", placement }
//

import SwiftUI
import GoogleMobileAds
import Combine

// Production banner unit (Salom AI), overridable via /ads/config.
// NOTE: never ship Google's test banner unit in a released build.
private let kDefaultBannerUnitID = "ca-app-pub-3378454853146779/5712979370"

private let kSlotHeight: CGFloat = 76

// MARK: - House ads (our own products)

private struct BannerCopy {
    let uz: String
    let cyrl: String
    let ru: String
    let en: String

    func pick(_ languageCode: String) -> String {
        switch languageCode {
        case "uz-Cyrl": cyrl
        case "ru": ru
        case "en": en
        default: uz
        }
    }
}

private struct HouseAd: Identifiable {
    let id: String
    let asset: String          // Assets.xcassets image name
    let brand: String
    let headline: BannerCopy
    let subline: BannerCopy
    let cta: BannerCopy
    let url: URL
    let grad: [String]         // hex stops for the CTA pill
    var colors: [Color] { grad.map { Color(hex: $0) } }
}

private let kHouseAds: [HouseAd] = [
    HouseAd(id: "fera", asset: "fera-ad", brand: "Fera Tech",
            headline: .init(uz: "Sayt, ilova yoki bot kerakmi?", cyrl: "Сайт, илова ёки бот керакми?", ru: "Нужен сайт, приложение или бот?", en: "Need a website, app or bot?"),
            subline: .init(uz: "Veb, ilova, bot va AI avtomatlashtirish", cyrl: "Веб, илова, бот ва AI автоматлаштириш", ru: "Сайты, приложения, боты и AI-автоматизация", en: "Websites, apps, bots and AI automation"),
            cta: .init(uz: "Batafsil", cyrl: "Батафсил", ru: "Подробнее", en: "Learn more"),
            url: URL(string: "https://fera-tech.com/uz")!,
            grad: ["#0EA5E9", "#0284C7"]),
    HouseAd(id: "bandmate", asset: "bandmate-ad", brand: "BandMate",
            headline: .init(uz: "Ingliz tilida bemalol gapiring", cyrl: "Инглиз тилида бемалол гапиринг", ru: "Говорите по-английски свободно", en: "Speak English with confidence"),
            subline: .init(uz: "AI hamroh bilan har kuni suhbat", cyrl: "AI ҳамроҳ билан ҳар куни суҳбат", ru: "Ежедневная практика с AI", en: "Daily practice with an AI partner"),
            cta: .init(uz: "Sinab ko‘rish", cyrl: "Синаб кўриш", ru: "Попробовать", en: "Try it"),
            url: URL(string: "https://bandmate.uz/")!,
            grad: ["#3B82F6", "#6366F1"]),
    HouseAd(id: "business", asset: "business-ad", brand: "Salom AI Biznes",
            headline: .init(uz: "Mijozlarga 24/7 avtomatik javob", cyrl: "Мижозларга 24/7 автоматик жавоб", ru: "Автоответы клиентам 24/7", en: "Reply to customers 24/7"),
            subline: .init(uz: "Telegram va Instagram uchun AI sotuvchi", cyrl: "Telegram ва Instagram учун AI сотувчи", ru: "AI-продавец для Telegram и Instagram", en: "AI sales assistant for Telegram and Instagram"),
            cta: .init(uz: "Bepul boshlash", cyrl: "Бепул бошлаш", ru: "Начать бесплатно", en: "Start free"),
            url: URL(string: "https://business.salom-ai.uz/")!,
            grad: ["#06B6D4", "#7C3AED"]),
]

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

// MARK: - House-ad card (white logo tile, matches the web design)

private struct HouseAdCard: View {
    let ad: HouseAd
    let languageCode: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                leadingArt
                VStack(alignment: .leading, spacing: 2) {
                    Text(ad.brand.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                        .lineLimit(1)
                    Text(ad.headline.pick(languageCode))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ad.subline.pick(languageCode))
                        .font(.system(size: 11.5))
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(ad.cta.pick(languageCode))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: ad.colors, startPoint: .leading, endPoint: .trailing)
                        )
                    )
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // White tile so the (blue) brand logos read clearly — mirrors the web ad.
    @ViewBuilder private var leadingArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white)
            if let ui = UIImage(named: ad.asset) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(ad.colors.first ?? .blue)
            }
        }
        .frame(width: 56, height: 56)
    }
}

// MARK: - Premium, free-users-only banner slot (carousel)

struct BannerAdSlot: View {
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    @ObservedObject private var subs = SubscriptionManager.shared
    @Environment(\.openURL) private var openURL

    @State private var unitID: String?
    @State private var showPaywall = false
    /// Whether AdMob actually returned an ad. When false, its page shows a house ad.
    @State private var adFilled = false
    /// Carousel page (0..<kHouseAds.count = house ads, last = AdMob).
    @State private var page = 0
    /// Products whose impression we've already logged this appearance.
    @State private var impressed: Set<String> = []

    // Total pages = every house ad + one AdMob page.
    private var pageCount: Int { kHouseAds.count + 1 }
    private var admobTag: Int { kHouseAds.count }

    // Rotate every 3s.
    private let rotation = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var resolvedUnitID: String { unitID ?? kDefaultBannerUnitID }

    var body: some View {
        Group {
            if !subs.isPro {
                VStack(spacing: 4) {
                    HStack {
                        Text(BannerCopy(uz: "Reklama", cyrl: "Реклама", ru: "Реклама", en: "Ad").pick(languageCode))
                            .font(.system(size: 9, weight: .medium))
                            .tracking(0.5)
                            .foregroundColor(SalomTheme.Colors.textTertiary)
                        Spacer()
                        Button {
                            HapticManager.shared.fire(.lightImpact)
                            Analytics.shared.track("ad_dismiss", ["surface": "ios_chat", "placement": "carousel"])
                            showPaywall = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                    }

                    carousel
                        .frame(height: kSlotHeight)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SalomTheme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(SalomTheme.Colors.border, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
        }
        .task { await loadConfig() }
        .onReceive(rotation) { _ in
            withAnimation(.easeInOut(duration: 0.5)) { page = (page + 1) % pageCount }
            trackImpression(page)
        }
        .onAppear {
            print("🪧 BannerAdSlot appear — isPro=\(subs.isPro)")
            trackImpression(0)
        }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet(context: .onboardingPersona, source: "ios_house_ad") }
    }

    @ViewBuilder private var carousel: some View {
        TabView(selection: $page) {
            ForEach(Array(kHouseAds.enumerated()), id: \.element.id) { idx, ad in
                HouseAdCard(ad: ad, languageCode: languageCode, onTap: { openHouseAd(ad) })
                    .tag(idx)
            }

            // Last page: AdMob always mounted (so it can load); a house-ad backup
            // sits ON TOP and is removed only once a real ad fills.
            ZStack {
                BannerAdView(adUnitID: resolvedUnitID,
                             width: UIScreen.main.bounds.width - 32,
                             onResult: { ok in
                                 withAnimation(.easeInOut(duration: 0.25)) { adFilled = ok }
                             })
                if !adFilled {
                    HouseAdCard(ad: kHouseAds[0], languageCode: languageCode, onTap: { openHouseAd(kHouseAds[0]) })
                }
            }
            .tag(admobTag)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func openHouseAd(_ ad: HouseAd) {
        HapticManager.shared.fire(.lightImpact)
        Analytics.shared.track("ad_click", ["product": ad.id, "surface": "ios_chat", "placement": "carousel"])
        openURL(ad.url)
    }

    private func trackImpression(_ index: Int) {
        guard index < kHouseAds.count else { return }   // AdMob page: not a house impression
        let ad = kHouseAds[index]
        guard !impressed.contains(ad.id) else { return }
        impressed.insert(ad.id)
        Analytics.shared.track("ad_impression", ["product": ad.id, "surface": "ios_chat", "placement": "carousel"])
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
