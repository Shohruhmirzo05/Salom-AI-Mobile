//
//  ProductShowcaseView.swift
//  Salom-Ai-iOS
//
//  "Bizning boshqa mahsulotlarimiz" — big house-ad cards for our own products
//  (BandMate, Salom AI Biznes, Fera Tech) shown on the Ilovalar hub. Mirrors the
//  web ProductShowcase. Free users only (hidden for Pro). Reports the same ad
//  analytics schema: ad_impression / ad_click, props { product, surface, placement }.
//

import SwiftUI

private struct ShowcaseCopy {
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

private struct HouseProduct: Identifiable {
    let id: String
    let asset: String        // Assets.xcassets logo name
    let brand: String
    let headline: ShowcaseCopy
    let sub: ShowcaseCopy
    let chips: [ShowcaseCopy]
    let cta: ShowcaseCopy
    let url: URL
    let grad: [String]
    var colors: [Color] { grad.map { Color(hex: $0) } }
}

private let kShowcase: [HouseProduct] = [
    HouseProduct(id: "bandmate", asset: "bandmate-ad", brand: "BandMate",
                 headline: .init(uz: "Ingliz tilida bemalol gapiring", cyrl: "Инглиз тилида бемалол гапиринг", ru: "Говорите по-английски свободно", en: "Speak English with confidence"),
                 sub: .init(uz: "AI hamroh bilan har kuni 5 daqiqa suhbat — xatolar o‘zbekcha izohlanadi", cyrl: "AI ҳамроҳ билан ҳар куни 5 дақиқа суҳбат — хатолар ўзбекча изоҳланади", ru: "Практикуйтесь с AI по 5 минут в день — ошибки объясняются на узбекском", en: "Practice with an AI partner for 5 minutes a day, with mistakes explained in Uzbek"),
                 chips: [
                    .init(uz: "IELTS", cyrl: "IELTS", ru: "IELTS", en: "IELTS"),
                    .init(uz: "Kunlik amaliyot", cyrl: "Кунлик амалиёт", ru: "Ежедневная практика", en: "Daily practice"),
                    .init(uz: "O‘zbekcha izoh", cyrl: "Ўзбекча изоҳ", ru: "Объяснения на узбекском", en: "Uzbek explanations"),
                 ],
                 cta: .init(uz: "Ochish", cyrl: "Очиш", ru: "Открыть", en: "Open"),
                 url: URL(string: "https://bandmate.uz/")!,
                 grad: ["#2563EB", "#4F46E5"]),
    HouseProduct(id: "business", asset: "business-ad", brand: "Salom AI Biznes",
                 headline: .init(uz: "Mijozlarga 24/7 avtomatik javob", cyrl: "Мижозларга 24/7 автоматик жавоб", ru: "Автоответы клиентам 24/7", en: "Reply to customers 24/7"),
                 sub: .init(uz: "Telegram va Instagram uchun AI sotuvchi — buyurtmalarni o‘zi qabul qiladi", cyrl: "Telegram ва Instagram учун AI сотувчи — буюртмаларни ўзи қабул қилади", ru: "AI-продавец для Telegram и Instagram — сам принимает заказы", en: "An AI sales assistant for Telegram and Instagram that takes orders"),
                 chips: [
                    .init(uz: "Telegram", cyrl: "Telegram", ru: "Telegram", en: "Telegram"),
                    .init(uz: "Instagram", cyrl: "Instagram", ru: "Instagram", en: "Instagram"),
                    .init(uz: "24/7", cyrl: "24/7", ru: "24/7", en: "24/7"),
                 ],
                 cta: .init(uz: "Bepul sinab ko‘rish", cyrl: "Бепул синаб кўриш", ru: "Попробовать бесплатно", en: "Try for free"),
                 url: URL(string: "https://business.salom-ai.uz/")!,
                 grad: ["#0891B2", "#7C3AED"]),
    HouseProduct(id: "fera", asset: "fera-ad", brand: "Fera Tech",
                 headline: .init(uz: "Sayt, ilova yoki Telegram bot kerakmi?", cyrl: "Сайт, илова ёки Telegram бот керакми?", ru: "Нужен сайт, приложение или Telegram-бот?", en: "Need a website, app or Telegram bot?"),
                 sub: .init(uz: "Veb, mobil ilova, bot va AI avtomatlashtirish — bepul konsultatsiya", cyrl: "Веб, мобил илова, бот ва AI автоматлаштириш — бепул консультация", ru: "Сайты, приложения, боты и AI-автоматизация — консультация бесплатно", en: "Websites, mobile apps, bots and AI automation — free consultation"),
                 chips: [
                    .init(uz: "Veb", cyrl: "Веб", ru: "Веб", en: "Web"),
                    .init(uz: "Ilova", cyrl: "Илова", ru: "Приложение", en: "App"),
                    .init(uz: "Bot", cyrl: "Бот", ru: "Бот", en: "Bot"),
                    .init(uz: "AI", cyrl: "AI", ru: "AI", en: "AI"),
                 ],
                 cta: .init(uz: "Batafsil", cyrl: "Батафсил", ru: "Подробнее", en: "Learn more"),
                 url: URL(string: "https://fera-tech.com/uz")!,
                 grad: ["#0B1220", "#0284C7"]),
]

struct ProductShowcaseView: View {
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    @ObservedObject private var subs = SubscriptionManager.shared
    @Environment(\.openURL) private var openURL
    @State private var impressed = false

    var body: some View {
        Group {
            if !subs.isPro {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ShowcaseCopy(uz: "REKLAMA", cyrl: "РЕКЛАМА", ru: "РЕКЛАМА", en: "AD").pick(languageCode))
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(SalomTheme.Colors.textTertiary)
                        Text(ShowcaseCopy(uz: "Bizning boshqa mahsulotlarimiz", cyrl: "Бизнинг бошқа маҳсулотларимиз", ru: "Другие наши продукты", en: "More products from our team").pick(languageCode))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                    }
                    .padding(.top, 28)

                    ForEach(kShowcase) { p in
                        card(p)
                    }
                }
                .padding(.horizontal, 16)
                .onAppear {
                    guard !impressed else { return }
                    impressed = true
                    for p in kShowcase {
                        Analytics.shared.track("ad_impression",
                                               ["product": p.id, "surface": "ios_apps", "placement": "showcase"])
                    }
                }
            }
        }
    }

    @ViewBuilder private func card(_ p: HouseProduct) -> some View {
        Button {
            HapticManager.shared.fire(.lightImpact)
            Analytics.shared.track("ad_click", ["product": p.id, "surface": "ios_apps", "placement": "showcase"])
            openURL(p.url)
        } label: {
            // Content-sized (NOT a fixed height) so nothing is cramped — the card
            // grows to fit its text with even 20pt padding all around.
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white)
                        if let ui = UIImage(named: p.asset) {
                            Image(uiImage: ui).resizable().scaledToFit()
                                .frame(width: 30, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .frame(width: 42, height: 42)
                    Text(p.brand)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(p.headline.pick(languageCode))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(p.sub.pick(languageCode))
                        .font(.system(size: 13.5))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ShowcaseChipFlow(spacing: 7) {
                    ForEach(Array(p.chips.enumerated()), id: \.offset) { _, chip in
                        Text(chip.pick(languageCode))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.14)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }
                .padding(.top, 1)

                Text("\(p.cta.pick(languageCode))  →")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#0B1220"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.white))
                    .padding(.top, 2)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    LinearGradient(colors: p.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 220, height: 220)
                        .blur(radius: 50)
                        .offset(x: 130, y: -90)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Wraps longer Russian/English chips onto additional rows instead of pushing
/// the product card beyond the device width.
private struct ShowcaseChipFlow: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var lineWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth > 0, lineWidth + spacing + size.width > width {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += (lineWidth == 0 ? 0 : spacing) + min(size.width, width)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: totalHeight + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += min(size.width, bounds.width) + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
