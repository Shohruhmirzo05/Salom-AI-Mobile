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
            SalomTheme.Colors.bgMain.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    closeRow
                    hero
                    headline
                    priceCard
                    benefits
                    ctaButton
                    Text(String.appLocalized("Maxsus narx faqat siz uchun, cheklangan vaqtda."))
                        .font(.system(size: 11))
                        .foregroundColor(SalomTheme.Colors.textTertiary)
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

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            CachedImage(imageUrl: PaywallContextID.paymentRecovery.spec.imageURL)
                .frame(maxWidth: .infinity)
                .frame(height: 226)
                .clipped()
            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 8) {
                badge
                Text(offer.baseName)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(SalomTheme.Colors.accentPrimary.opacity(0.42), lineWidth: 1)
        )
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(SalomTheme.Colors.surfaceMuted)
                    .clipShape(Circle())
            }
        }
    }

    private var badge: some View {
        Text(String(format: String.appLocalized("-%lld%% CHEGIRMA"), offer.discountPct))
            .font(.system(size: 13, weight: .heavy))
            .tracking(1)
            .foregroundColor(SalomTheme.Colors.onAccent)
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
            Text(String.appLocalized("Maxsus narx faqat siz uchun, cheklangan vaqtda."))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(SalomTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
        }
    }

    private var priceCard: some View {
        VStack(spacing: 6) {
            Text(offer.baseName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(formatPrice(offer.promoPrice))
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
                Text(formatPrice(offer.basePrice))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(SalomTheme.Colors.textTertiary)
                    .strikethrough(true, color: SalomTheme.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SalomTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(hex: "#FF7A00").opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder private var benefits: some View {
        if let benefits = offer.benefits, !benefits.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(0..<min(3, benefits.count), id: \.self) { i in
                    if let line = offer.benefit(at: i, lang: languageCode) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(SalomTheme.Colors.accentPrimary)
                            Text(line)
                                .font(.system(size: 14))
                                .foregroundColor(SalomTheme.Colors.textPrimary)
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
            Text(String.appLocalized("Chegirmani olish"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(SalomTheme.Gradients.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: SalomTheme.Colors.accentPrimary.opacity(0.3), radius: 16, x: 0, y: 8)
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
