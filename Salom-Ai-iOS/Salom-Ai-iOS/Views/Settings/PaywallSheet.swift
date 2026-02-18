//
//  PaywallSheet.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 28/01/25.
//

import SwiftUI

// MARK: - Navigation model

enum PaymentStep: Hashable {
    case cardInput(planCode: String)
    case smsVerify(planCode: String, requestId: String, phoneHint: String)
}

// Environment key to dismiss the entire fullScreenCover from any depth
private struct DismissAllKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var dismissAll: () -> Void {
        get { self[DismissAllKey.self] }
        set { self[DismissAllKey.self] = newValue }
    }
}

// MARK: - PaywallSheet

struct PaywallSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            PaywallContent()
                .navigationDestination(for: PaymentStep.self) { step in
                    destinationView(for: step)
                }
        }
        .environment(\.dismissAll, { dismiss() })
        .task {
            if subscriptionManager.plans.isEmpty {
                await subscriptionManager.fetchPlans()
            }
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    @ViewBuilder func destinationView(for step: PaymentStep) -> some View {
        switch step {
        case .cardInput(let planCode):
            CardInputSheet(planCode: planCode) { requestId, phoneHint in
                path.append(
                    PaymentStep.smsVerify(
                        planCode: planCode,
                        requestId: requestId,
                        phoneHint: phoneHint
                    )
                )
            }
        case .smsVerify(let planCode, let requestId, let phoneHint):
            SMSVerifySheet(
                requestId: requestId,
                phoneHint: phoneHint,
                planCode: planCode,
                onSuccess: { dismiss() },
                onBack: {
                    if !path.isEmpty { path.removeLast() }
                }
            )
        }
    }

    // MARK: - Paywall content

    @ViewBuilder func PaywallContent() -> some View {
        VStack(spacing: 0) {
            Image("premium_paywall_header")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 300)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.85),
                            Color.clear,
                            Color.black.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Text("Cheklovsiz Imkoniyatlar")
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Salom AI Pro orqali sun'iy intellektning to'liq kuchidan foydalaning.")
                            .font(.body)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 14) {
                        BenefitRow(icon: "message.fill", title: "Cheklovsiz xabarlar", subtitle: "Murosasiz muloqot")
                        BenefitRow(icon: "bolt.fill", title: "Tezkor javoblar", subtitle: "Navbatsiz xizmat")
                        BenefitRow(icon: "speaker.wave.3.fill", title: "Ovozli rejim", subtitle: "Jonli suhbatlar")
                        BenefitRow(icon: "sparkles", title: "Keyingi avlod modellari", subtitle: "Eng aqlli javoblar")
                    }
                    
                    if let proPlan = subscriptionManager.plans.first(where: { $0.priceUzs > 0 }) {
                        Button {
                            HapticManager.shared.fire(.mediumImpact)
                            path.append(PaymentStep.cardInput(planCode: proPlan.code))
                        } label: {
                            HStack(spacing: 8) {
                                if subscriptionManager.isLoading {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("Pro ga o'tish — \(proPlan.priceUzs.formatted()) UZS/oy")
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                    Image(systemName: "arrow.right")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(SalomTheme.Colors.accentPrimary)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                        }
                    } else {
                        ProgressView().tint(.white)
                    }
                    
                    Button("Keyinroq") {
                        HapticManager.shared.fire(.lightImpact)
                        dismiss()
                    }
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .padding(24)
            }
        }
        .background(SalomTheme.Gradients.background)
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CloseButton { dismiss() }
            }
        }
    }
}

// MARK: - Standalone payment flow (used from SubscriptionView)

/// A NavigationStack-based payment flow that starts at card input.
/// Presented as fullScreenCover from SubscriptionView.
struct SubscriptionPaymentFlow: View {
    let planCode: String

    @Environment(\.dismiss) var dismiss
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            CardInputSheet(planCode: planCode) { requestId, phoneHint in
                path.append(
                    PaymentStep.smsVerify(
                        planCode: planCode,
                        requestId: requestId,
                        phoneHint: phoneHint
                    )
                )
            }
            .navigationDestination(for: PaymentStep.self) { step in
                switch step {
                case .smsVerify(let planCode, let requestId, let phoneHint):
                    SMSVerifySheet(
                        requestId: requestId,
                        phoneHint: phoneHint,
                        planCode: planCode,
                        onSuccess: { dismiss() },
                        onBack: {
                            if !path.isEmpty { path.removeLast() }
                        }
                    )
                default:
                    EmptyView()
                }
            }
        }
        .environment(\.dismissAll, { dismiss() })
    }
}

// MARK: - Reusable components
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
        }
    }
}

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Orqaga")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(SalomTheme.Colors.accentPrimary.opacity(0.1))
                .foregroundColor(SalomTheme.Colors.accentPrimary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(14)
    }
}
// MARK: - Previews

#Preview("Paywall – plans loaded") {
    let manager = SubscriptionManager.shared
    manager.plans = [
        SubscriptionPlan(
            code: "pro_monthly",
            name: "Pro",
            priceUzs: 49_000,
            monthlyMessages: nil,
            monthlyTokens: nil,
            benefits: nil
        )
    ]
    return NavigationStack { PaywallSheet() }
}

#Preview("Paywall – loading") {
    let manager = SubscriptionManager.shared
    manager.plans = []
    manager.isLoading = true
    return NavigationStack { PaywallSheet() }
}

