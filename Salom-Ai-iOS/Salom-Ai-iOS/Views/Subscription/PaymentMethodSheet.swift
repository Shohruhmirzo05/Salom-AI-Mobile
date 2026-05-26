//
//  PaymentMethodSheet.swift
//  Salom-Ai-iOS
//
//  Minimal payment-method selector with trust signals (Click logo, lock icons).
//

import SwiftUI

struct PaymentMethodSheet: View {
    let planCode: String
    let onChooseAutoRenew: () -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.dismissAll) var dismissAll
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selected: Method = .oneTime
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Method: Hashable { case oneTime, autoRenew }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

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
                    .foregroundColor(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
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
                .foregroundColor(.white.opacity(0.25))
            Image("click-logo")
                .resizable()
                .scaledToFit()
                .frame(height: 18)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9))
                Text("SSL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundColor(.white.opacity(0.35))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.04)))
        }
    }

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To'lov turi")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .tracking(-0.6)
            Text("Click orqali. Birini tanlang.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.45))
        }
    }

    @ViewBuilder private var options: some View {
        VStack(spacing: 10) {
            MethodRow(
                active: selected == .oneTime,
                icon: "arrow.up.right.square.fill",
                title: "Bir martalik",
                subtitle: "Click sahifasiga o'tasiz"
            ) {
                HapticManager.shared.fire(.lightImpact)
                withAnimation(.easeOut(duration: 0.15)) { selected = .oneTime }
            }
            MethodRow(
                active: selected == .autoRenew,
                icon: "arrow.triangle.2.circlepath",
                title: "Avtomatik yangilanish",
                subtitle: "Karta saqlanadi, har oy o'zi yangilanadi"
            ) {
                HapticManager.shared.fire(.lightImpact)
                withAnimation(.easeOut(duration: 0.15)) { selected = .autoRenew }
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
                        ProgressView().tint(.black)
                    } else {
                        Text("Davom etish")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(isLoading ? 0.7 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                Text("Click orqali xavfsiz to'lov")
                    .font(.system(size: 11))
            }
            .foregroundColor(.white.opacity(0.32))
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
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
            onChooseAutoRenew()
        case .oneTime:
            isLoading = true
            defer { isLoading = false }
            guard let urlString = await subscriptionManager.subscribeOneTime(planCode: planCode),
                  let url = URL(string: urlString)
            else {
                errorMessage = "To'lov havolasini olib bo'lmadi."
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
    let icon: String
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Radio
                Circle()
                    .strokeBorder(
                        active ? Color.white : Color.white.opacity(0.2),
                        lineWidth: active ? 5 : 1
                    )
                    .frame(width: 18, height: 18)
                    .animation(.easeOut(duration: 0.15), value: active)

                // Icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(active ? .white : .white.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundColor(.white.opacity(0.42))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(active ? 0.06 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        active ? Color.white.opacity(0.9) : Color.white.opacity(0.06),
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
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.45))
    }
}
