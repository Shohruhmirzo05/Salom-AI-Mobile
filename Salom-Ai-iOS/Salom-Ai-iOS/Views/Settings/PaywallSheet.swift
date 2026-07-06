//
//  PaywallSheet.swift
//  Salom-Ai-iOS
//
//  Minimal premium paywall. Daily price as the hero number (cheap framing),
//  monthly shown small for context. Benefits come from /subscriptions/plans
//  so admin changes propagate. Pulls Click + brand logos for trust.
//

import SwiftUI

/// Billing period for the paywalls' Oylik/Yillik toggle (shared across views).
enum BillingPeriod: Hashable { case yearly, monthly }

/// Shared helpers for pairing monthly↔yearly plans and computing savings.
enum PlanPeriodHelper {
    static func isYearly(_ p: SubscriptionPlan) -> Bool { (p.durationDays ?? 30) >= 300 }
    /// % cheaper vs paying the monthly counterpart for a whole year.
    static func savingsPct(_ plan: SubscriptionPlan, in all: [SubscriptionPlan]) -> Int? {
        guard isYearly(plan) else { return nil }
        let base = plan.code.replacingOccurrences(of: "_yearly", with: "")
        guard let m = all.first(where: { $0.code == base }) else { return nil }
        let full: Int = m.priceUzs * 12
        guard full > 0 else { return nil }
        let ratio: Double = Double(plan.priceUzs) / Double(full)
        let pct: Int = Int((1.0 - ratio) * 100.0)
        return pct > 0 ? pct : nil
    }
}

/// General ✓/✗ comparison shown on every plan card (matches web). The higher tier
/// gets every row; the lower tier shows the premium (proOnly) rows as ✗, so the
/// gap is obvious and users are nudged up. NOT exact per-plan limits.
struct PlanCompareFeature: Identifiable {
    let id = UUID()
    let label: String
    let proOnly: Bool
}
let planCompareFeatures: [PlanCompareFeature] = [
    .init(label: "📊 Taqdimot, referat va DTM", proOnly: false),
    .init(label: "🎨 Rasm yaratish va ovozli rejim", proOnly: false),
    .init(label: "🧠 Eng kuchli AI — Super Aqlli", proOnly: true),
    .init(label: "🚀 Yuqori limitlar — ko‘proq rasm va ovoz", proOnly: true),
    .init(label: "👑 Hamma imkoniyat — cheklovsiz", proOnly: true),
]

// MARK: - Navigation model

enum PaymentStep: Hashable {
    case methodChoice(planCode: String)
    case cardInput(planCode: String)
    case smsVerify(planCode: String, requestId: String, phoneHint: String)
}

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
    @State private var selectedPlanCode: String? = nil
    @State private var billingPeriod: BillingPeriod = .yearly   // prioritise yearly

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: PaymentStep.self) { step in
                    destinationView(for: step)
                }
        }
        .environment(\.dismissAll, { dismiss() })
        .task {
            Analytics.shared.track("paywall_shown", ["surface": "ios"])
            if subscriptionManager.plans.isEmpty {
                await subscriptionManager.fetchPlans()
            }
            if selectedPlanCode == nil {
                selectedPlanCode = recommendedPlan?.code
            }
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    @ViewBuilder private var content: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerArt
                    headerCopy
                    highlightsStrip
                    if hasYearly { billingToggle }
                    planList
                    if let selected = selectedPlan {
                        benefitsBlock(for: selected)
                    }
                    trustRow
                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 130)
            }

            stickyCTA
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Header art (Salom AI mascot)

    @ViewBuilder private var headerArt: some View {
        ZStack(alignment: .bottom) {
            // Subtle radial glow behind the mascot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 160
                    )
                )
                .frame(height: 220)
                .blur(radius: 8)
                .offset(y: 20)

            Image("main-character")
                .resizable()
                .scaledToFit()
                .frame(height: 160)
        }
        .frame(maxWidth: .infinity)
    }

    // Always-visible premium highlights (independent of admin-managed benefits),
    // so the NEW AI presentations feature is sold on the paywall.
    @ViewBuilder private var highlightsStrip: some View {
        let items: [(String, String)] = [
            ("rectangle.on.rectangle.angled", "AI presentatsiyalar — PPTX va PDF"),
            ("bolt.fill", "Kuchliroq modellar va yuqori limitlar"),
            ("waveform", "Real vaqt ovozli AI"),
        ]
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.1) { item in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 30, height: 30)
                        Image(systemName: item.0).font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                    }
                    Text(item.1).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.85))
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    @ViewBuilder private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("app-icon-transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text("Salom AI Pro")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .tracking(-0.4)
            }
            Text("Cheklovsiz suhbat, ovoz va eng aqlli modellar.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .lineSpacing(2)
        }
    }

    // MARK: - Plans

    // Oylik / Yillik segmented toggle — defaults to Yillik so users see the deal.
    @ViewBuilder private var billingToggle: some View {
        HStack(spacing: 4) {
            ForEach([BillingPeriod.yearly, BillingPeriod.monthly], id: \.self) { p in
                Button {
                    HapticManager.shared.fire(.lightImpact)
                    withAnimation(.easeOut(duration: 0.18)) {
                        billingPeriod = p
                        // recommendedPlan is already scoped to the new period.
                        selectedPlanCode = recommendedPlan?.code
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(p == .yearly ? "Yillik" : "Oylik")
                            .font(.system(size: 13.5, weight: .semibold))
                        if p == .yearly, maxSavingsPct > 0 {
                            Text("−\(maxSavingsPct)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(Color.green))
                        }
                    }
                    .foregroundColor(billingPeriod == p ? .black : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(billingPeriod == p ? Color.white : Color.clear)
                    )
                    .contentShape(Rectangle())   // whole segment tappable, not just the text
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    @ViewBuilder private var planList: some View {
        if paidPlans.isEmpty {
            ProgressView()
                .tint(.white.opacity(0.5))
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            VStack(spacing: 10) {
                ForEach(displayedPlans, id: \.code) { plan in
                    DailyPriceRow(
                        plan: plan,
                        selected: selectedPlanCode == plan.code,
                        isRecommended: plan.code == recommendedPlan?.code,
                        savingsPct: savingsPct(for: plan)
                    ) {
                        HapticManager.shared.fire(.lightImpact)
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedPlanCode = plan.code
                        }
                    }
                }
            }
        }
    }

    // MARK: - Benefits

    @ViewBuilder private func benefitsBlock(for plan: SubscriptionPlan) -> some View {
        let isPro = plan.code.contains("pro")
        VStack(alignment: .leading, spacing: 10) {
            Text("\(plan.name) imkoniyatlari")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.6)
                .textCase(.uppercase)

            // ✓/✗ comparison — Pro gets all rows; lower tier shows premium rows as ✗.
            VStack(alignment: .leading, spacing: 9) {
                ForEach(planCompareFeatures) { f in
                    let included = isPro || !f.proOnly
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(included ? 0.08 : 0.04))
                                .frame(width: 18, height: 18)
                            Image(systemName: included ? "checkmark" : "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(included ? 0.85 : 0.3))
                        }
                        .padding(.top, 1)
                        Text(f.label)
                            .font(.system(size: 13.5))
                            .foregroundColor(.white.opacity(included ? 0.78 : 0.3))
                            .strikethrough(!included, color: .white.opacity(0.3))
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    // MARK: - Trust row

    @ViewBuilder private var trustRow: some View {
        HStack(spacing: 8) {
            trustChip(icon: "lock.fill", label: "Xavfsiz")
            trustChip(icon: "arrow.uturn.backward", label: "Istalgan vaqt bekor")
            trustClickChip()
        }
    }

    private func trustChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.5))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.04))
        )
    }

    private func trustClickChip() -> some View {
        HStack(spacing: 5) {
            Image("click-logo")
                .resizable()
                .scaledToFit()
                .frame(height: 12)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.04)))
    }

    // MARK: - CTA

    @ViewBuilder private var stickyCTA: some View {
        if let selected = selectedPlan {
            VStack(spacing: 8) {
                Button {
                    HapticManager.shared.fire(.mediumImpact)
                    Analytics.shared.track("paywall_plan_clicked", ["plan": selected.code])
                    path.append(PaymentStep.methodChoice(planCode: selected.code))
                } label: {
                    HStack(spacing: 6) {
                        Text("Boshlash")
                            .font(.system(size: 16, weight: .semibold))
                        Text("·")
                            .font(.system(size: 16, weight: .semibold))
                            .opacity(0.4)
                        Text("\(formatPrice(Int(selected.pricePerDay.rounded()))) / kun")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("Obuna avtomatik yangilanadi · to'lovlar qaytarilmaydi")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                Link("Foydalanish shartlari", destination: URL(string: "https://salom-ai.uz/terms-of-service")!)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
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
    }

    // MARK: - Navigation

    @ViewBuilder func destinationView(for step: PaymentStep) -> some View {
        switch step {
        case .methodChoice(let planCode):
            PaymentMethodSheet(planCode: planCode) {
                path.append(PaymentStep.cardInput(planCode: planCode))
            }
        case .cardInput(let planCode):
            CardInputSheet(planCode: planCode) { requestId, phoneHint in
                path.append(PaymentStep.smsVerify(planCode: planCode, requestId: requestId, phoneHint: phoneHint))
            }
        case .smsVerify(let planCode, let requestId, let phoneHint):
            SMSVerifySheet(
                requestId: requestId,
                phoneHint: phoneHint,
                planCode: planCode,
                onSuccess: { dismiss() },
                onBack: { if !path.isEmpty { path.removeLast() } }
            )
        }
    }

    // MARK: - Derived

    private var paidPlans: [SubscriptionPlan] {
        subscriptionManager.plans
            .filter { $0.isPaid }
            .sorted { $0.priceUzs < $1.priceUzs }
    }

    // Plans for the currently-selected billing period.
    private var displayedPlans: [SubscriptionPlan] {
        paidPlans.filter { p in
            let d = p.durationDays ?? 30
            return billingPeriod == .yearly ? d >= 300 : d < 300
        }
    }
    private var hasYearly: Bool { paidPlans.contains { ($0.durationDays ?? 30) >= 300 } }

    private var recommendedPlan: SubscriptionPlan? {
        let list = displayedPlans
        if list.count >= 2 { return list[1] }   // the higher tier
        return list.first
    }

    /// % cheaper vs paying the monthly counterpart for a whole year.
    private func savingsPct(for plan: SubscriptionPlan) -> Int? {
        guard (plan.durationDays ?? 30) >= 300 else { return nil }
        let base = plan.code.replacingOccurrences(of: "_yearly", with: "")
        guard let m = paidPlans.first(where: { $0.code == base }) else { return nil }
        let full = m.priceUzs * 12
        guard full > 0 else { return nil }
        let pct = Int((1.0 - Double(plan.priceUzs) / Double(full)) * 100.0)
        return pct > 0 ? pct : nil
    }
    private var maxSavingsPct: Int {
        paidPlans.compactMap { savingsPct(for: $0) }.max() ?? 0
    }

    private var selectedPlan: SubscriptionPlan? {
        guard let code = selectedPlanCode else { return displayedPlans.first }
        return paidPlans.first { $0.code == code }
    }
}

// MARK: - Plan row with daily-price as hero

private struct DailyPriceRow: View {
    let plan: SubscriptionPlan
    let selected: Bool
    let isRecommended: Bool
    var savingsPct: Int? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    // Radio
                    Circle()
                        .strokeBorder(
                            selected ? Color.white : Color.white.opacity(0.18),
                            lineWidth: selected ? 5 : 1
                        )
                        .frame(width: 18, height: 18)
                        .animation(.easeOut(duration: 0.15), value: selected)

                    // Plan name + period
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(plan.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            if isRecommended {
                                Text("Tavsiya")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.3)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(Color.white)
                                    )
                            }
                        }
                        HStack(spacing: 6) {
                            Text(periodLabel)
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.4))
                            if let s = savingsPct, s > 0 {
                                Text("−\(s)% tejang")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    // BIG daily price (hero)
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatPrice(Int(plan.pricePerDay.rounded())))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(-0.4)
                            Text("/ kun")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        // Tiny total below — keep it small, this is intentional
                        Text("\(formatPrice(plan.priceUzs)) / \(shortPeriodLabel)")
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.32))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.06 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? Color.white.opacity(0.9) : Color.white.opacity(0.06),
                        lineWidth: selected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var periodLabel: String {
        let days = plan.durationDays ?? 30
        switch days {
        case 30:  return "Oylik obuna"
        case 90:  return "3 oylik obuna"
        case 365: return "Yillik obuna"
        default:  return "\(days) kun"
        }
    }

    private var shortPeriodLabel: String {
        let days = plan.durationDays ?? 30
        switch days {
        case 30:  return "oy"
        case 90:  return "3 oy"
        case 365: return "yil"
        default:  return "\(days) kun"
        }
    }
}

// MARK: - Standalone payment flow

struct SubscriptionPaymentFlow: View {
    let planCode: String

    @Environment(\.dismiss) var dismiss
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            PaymentMethodSheet(planCode: planCode) {
                path.append(PaymentStep.cardInput(planCode: planCode))
            }
            .navigationDestination(for: PaymentStep.self) { step in
                switch step {
                case .cardInput(let planCode):
                    CardInputSheet(planCode: planCode) { requestId, phoneHint in
                        path.append(PaymentStep.smsVerify(planCode: planCode, requestId: requestId, phoneHint: phoneHint))
                    }
                case .smsVerify(let planCode, let requestId, let phoneHint):
                    SMSVerifySheet(
                        requestId: requestId,
                        phoneHint: phoneHint,
                        planCode: planCode,
                        onSuccess: { dismiss() },
                        onBack: { if !path.isEmpty { path.removeLast() } }
                    )
                default: EmptyView()
                }
            }
        }
        .environment(\.dismissAll, { dismiss() })
    }
}

// MARK: - Helpers

private func formatPrice(_ uzs: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = " "
    return (f.string(from: NSNumber(value: uzs)) ?? "\(uzs)") + " UZS"
}
