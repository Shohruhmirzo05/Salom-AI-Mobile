//
//  WinBackOfferSheet.swift
//  Salom-Ai-iOS
//
//  Win-back popup shown to users who started a payment but never finished.
//  Mirrors the web recovery-offer: a discounted promo plan with a clear % off,
//  routed straight into the Click payment flow. Free for everyone else.
//

import SwiftUI

struct WinBackOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"

    let offer: RecoveryOffer
    @State private var payFor: IdentifiablePlanCode?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // "Winning" celebration burst when the offer opens.
            ConfettiBurst()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    closeRow
                    badge
                    headline
                    priceCard
                    benefits
                    ctaButton
                    Text("Maxsus narx faqat siz uchun, cheklangan vaqtda.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .onAppear { Analytics.shared.track("winback_shown", ["plan": offer.promoCode, "discount": offer.discountPct]) }
        .fullScreenCover(item: $payFor) { sel in
            NavigationStack {
                SubscriptionPaymentFlow(planCode: sel.code)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { payFor = nil } label: { Image(systemName: "xmark") }
                        }
                    }
            }
        }
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
        }
    }

    private var badge: some View {
        Text("-\(offer.discountPct)% CHEGIRMA")
            .font(.system(size: 13, weight: .heavy))
            .tracking(1)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [Color(hex: "#FF7A00"), Color(hex: "#FF2D78")],
                                   startPoint: .leading, endPoint: .trailing)
                )
            )
    }

    private var headline: some View {
        VStack(spacing: 8) {
            Text("Sizni qaytarib olmoqchimiz! 🎁")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Pro obunani maxsus, bir martalik chegirma bilan oching.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    private var priceCard: some View {
        VStack(spacing: 6) {
            Text(offer.baseName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(formatPrice(offer.promoPrice))
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
                Text(formatPrice(offer.basePrice))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .strikethrough(true, color: .white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: "#FF7A00").opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder private var benefits: some View {
        if let benefits = offer.benefits, !benefits.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(0..<min(5, benefits.count), id: \.self) { i in
                    if let line = offer.benefit(at: i, lang: languageCode) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(SalomTheme.Colors.accentPrimary)
                            Text(line)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ctaButton: some View {
        Button {
            HapticManager.shared.fire(.mediumImpact)
            Analytics.shared.track("winback_accepted", ["plan": offer.promoCode])
            payFor = IdentifiablePlanCode(code: offer.promoCode)
        } label: {
            Text("Chegirmani olish")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func formatPrice(_ uzs: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        return (f.string(from: NSNumber(value: uzs)) ?? "\(uzs)") + " UZS"
    }
}

// MARK: - Confetti "winning" celebration (native SwiftUI, no Lottie dependency)

private struct ConfettiBurst: View {
    var count: Int = 48
    @State private var on = false

    private struct Piece: Identifiable {
        let id: Int
        let color: Color
        let xEnd: CGFloat
        let size: CGFloat
        let delay: Double
        let rot: Double
        let fall: CGFloat
    }

    private let pieces: [Piece]

    init(count: Int = 48) {
        self.count = count
        let palette: [Color] = [
            Color(hex: "#1ED6FF"), Color(hex: "#7C3AED"), Color(hex: "#FF7A00"),
            Color(hex: "#FF2D78"), Color(hex: "#FFD23F"), Color(hex: "#22C55E"),
        ]
        pieces = (0..<count).map { i in
            Piece(
                id: i,
                color: palette[i % palette.count],
                xEnd: CGFloat.random(in: -190...190),
                size: CGFloat.random(in: 6...12),
                delay: Double.random(in: 0...0.35),
                rot: Double.random(in: 180...900),
                fall: CGFloat.random(in: 480...780)
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.7)
                    .rotationEffect(.degrees(on ? p.rot : 0))
                    .offset(x: on ? p.xEnd : 0, y: on ? p.fall : -60)
                    .opacity(on ? 0 : 1)
                    .animation(.easeOut(duration: 1.8).delay(p.delay), value: on)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear { on = true }
    }
}
