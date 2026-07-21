//
//  PaymentMethodSheet.swift
//  Salom-Ai-iOS
//
//  Minimal payment-method selector with trust signals (Click logo, lock icons).
//

import SwiftUI

/// Adaptive Click wordmark. The bundled full logo has white lettering for dark
/// surfaces, so it disappears in light mode; keep the official mark and render
/// the name with the app's semantic foreground instead.
struct ClickBrandMark: View {
    var iconSize: CGFloat = 26
    var fontSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 7) {
            Image("click-icon")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
            Text("click")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(SalomTheme.Colors.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Click")
    }
}

struct PaymentMethodSheet: View {
    let planCode: String
    let onChooseAutoRenew: () -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.dismissAll) var dismissAll
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selected: Method = .autoRenew
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var paymeEnabled = false

    enum Method: Hashable { case oneTime, autoRenew, payme }

    var body: some View {
        ZStack(alignment: .bottom) {
            SalomTheme.Colors.bgMain.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    brandRow
                    header
                    options
                    if let errorMessage {
                        errorRow(errorMessage)
                    }
                    trustStrip
                    Spacer(minLength: 140)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
            }

            stickyCTA
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("To'lov")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await loadPaymentConfig() }
    }

    /// Payme appears only when the backend enables it (off in production).
    @MainActor
    private func loadPaymentConfig() async {
        let url = APIClient.shared.baseURL.appendingPathComponent("subscriptions/payment-config")
        guard let token = TokenStore.shared.accessToken else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            paymeEnabled = (json["payme_enabled"] as? Bool) ?? false
        }
    }

    // MARK: - Sections

    @ViewBuilder private var brandRow: some View {
        HStack(spacing: 10) {
            Image("app-icon-transparent")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textTertiary)
            // Both payment partners we work with.
            HStack(spacing: 7) {
                ProviderChip(logo: "click-icon", size: 30)
                ProviderChip(logo: "payme-logo", size: 30)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9))
                Text("SSL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundColor(SalomTheme.Colors.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(SalomTheme.Colors.surfaceMuted))
        }
    }

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To'lov turini tanlang")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textPrimary)
                .tracking(-0.6)
            Text("Sizga qulay usulni tanlang.")
                .font(.system(size: 14))
                .foregroundColor(SalomTheme.Colors.textSecondary)
        }
    }

    @ViewBuilder private var options: some View {
        VStack(spacing: 10) {
            MethodRow(
                active: selected == .autoRenew,
                logo: "click-icon",
                badge: "arrow.triangle.2.circlepath",
                title: "Karta (avto-yangilanish)",
                subtitle: "Karta saqlanadi, har oy o'zi yangilanadi"
            ) {
                HapticManager.shared.fire(.lightImpact)
                withAnimation(.easeOut(duration: 0.15)) { selected = .autoRenew }
            }
            MethodRow(
                active: selected == .oneTime,
                logo: "click-icon",
                badge: nil,
                title: "Click (bir martalik)",
                subtitle: "Click sahifasiga o'tasiz"
            ) {
                HapticManager.shared.fire(.lightImpact)
                withAnimation(.easeOut(duration: 0.15)) { selected = .oneTime }
            }
            if paymeEnabled {
                MethodRow(
                    active: selected == .payme,
                    logo: "payme-logo",
                    badge: nil,
                    title: "Payme (bir martalik)",
                    subtitle: "Payme sahifasiga o'tasiz"
                ) {
                    HapticManager.shared.fire(.lightImpact)
                    withAnimation(.easeOut(duration: 0.15)) { selected = .payme }
                }
            }
        }
    }

    @ViewBuilder private var trustStrip: some View {
        HStack(spacing: 14) {
            TrustItem(icon: "lock.fill", label: "Xavfsiz")
            TrustItem(icon: "checkmark.shield.fill", label: "PCI DSS")
            TrustItem(icon: "eye.slash.fill", label: "Maxfiy")
            Spacer()
        }
        .padding(.top, 4)
    }

    @ViewBuilder private var stickyCTA: some View {
        VStack(spacing: 8) {
            Button {
                HapticManager.shared.fire(.mediumImpact)
                Task { await handleContinue() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(SalomTheme.Colors.onAccent)
                    } else {
                        Text("Davom etish")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SalomTheme.Colors.onAccent)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SalomTheme.Colors.onAccent.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(SalomTheme.Colors.accentSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(isLoading ? 0.7 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                Text("SSL bilan himoyalangan xavfsiz to'lov")
                    .font(.system(size: 11))
            }
            .foregroundColor(SalomTheme.Colors.textTertiary)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [SalomTheme.Colors.bgMain.opacity(0), SalomTheme.Colors.bgMain],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 130)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }

    private func errorRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 13))
        }
        .foregroundColor(Color(hex: "#F97373"))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#F97373").opacity(0.08))
        )
    }

    @MainActor
    private func handleContinue() async {
        errorMessage = nil
        switch selected {
        case .autoRenew:
            Analytics.shared.track("payment_started", ["plan": planCode, "provider": "click_token"])
            onChooseAutoRenew()
        case .oneTime:
            Analytics.shared.track("payment_started", ["plan": planCode, "provider": "click"])
            isLoading = true
            defer { isLoading = false }
            guard let urlString = await subscriptionManager.subscribeOneTime(planCode: planCode),
                  let url = URL(string: urlString)
            else {
                errorMessage = String.appLocalized("To'lov havolasini olib bo'lmadi.")
                return
            }
            await UIApplication.shared.open(url)
            dismissAll()
        case .payme:
            Analytics.shared.track("payment_started", ["plan": planCode, "provider": "payme"])
            isLoading = true
            defer { isLoading = false }
            guard let urlString = await subscriptionManager.subscribeCheckout(planCode: planCode, provider: "payme"),
                  let url = URL(string: urlString)
            else {
                errorMessage = String.appLocalized("To'lov havolasini olib bo'lmadi.")
                return
            }
            await UIApplication.shared.open(url)
            dismissAll()
        }
    }
}

// MARK: - Components

private struct MethodRow: View {
    let active: Bool
    let logo: String
    let badge: String?
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Radio
                Circle()
                    .strokeBorder(
                        active ? SalomTheme.Colors.accentPrimary : SalomTheme.Colors.border,
                        lineWidth: active ? 5 : 1
                    )
                    .frame(width: 18, height: 18)
                    .animation(.easeOut(duration: 0.15), value: active)

                // Real provider logo on a white chip.
                ProviderChip(logo: logo, size: 40, badge: badge)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String.appLocalized(title))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.textPrimary)
                    Text(String.appLocalized(subtitle))
                        .font(.system(size: 12.5))
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(active ? SalomTheme.Colors.surfaceMuted : SalomTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        active ? SalomTheme.Colors.accentPrimary : SalomTheme.Colors.border,
                        lineWidth: active ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TrustItem: View {
    let icon: String
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(String.appLocalized(label))
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(SalomTheme.Colors.textSecondary)
    }
}

/// A provider's official logo on a white rounded chip. Optional `badge` overlays a
/// small accent glyph (e.g. auto-renew) in the bottom-trailing corner.
private struct ProviderChip: View {
    let logo: String
    var size: CGFloat = 40
    var badge: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(Color.white)
            .frame(width: size, height: size)
            .overlay(
                Image(logo)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)
            )
            .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if let badge {
                    Image(systemName: badge)
                        .font(.system(size: size * 0.26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(size * 0.1)
                        .background(Circle().fill(Color(hex: "#1ED6FF")))
                        .overlay(Circle().strokeBorder(Color.black, lineWidth: 1.5))
                        .offset(x: size * 0.14, y: size * 0.14)
                }
            }
    }
}
