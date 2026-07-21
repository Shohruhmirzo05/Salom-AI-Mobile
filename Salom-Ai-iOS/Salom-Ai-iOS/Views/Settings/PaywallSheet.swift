//
//  PaywallSheet.swift
//  Salom-Ai-iOS
//
//  Contextual, image-led premium paywall. The visual proves the result first;
//  the charged price and payment terms stay explicit and easy to scan.
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

    let context: PaywallContextID
    let source: String

    @State private var path = NavigationPath()
    @State private var selectedPlanCode: String? = nil
    @State private var billingPeriod: BillingPeriod

    // "Why didn't you pay?" survey — shown once (per 30d) when the user closes the
    // paywall without subscribing. Feeds the admin Insights breakdown.
    @State private var askSurvey = false
    @State private var showSurvey = false
    @State private var surveyed = false

    init(context: PaywallContextID = .general, source: String = "ios") {
        self.context = context
        self.source = source
        _billingPeriod = State(initialValue: context.spec.defaultPeriod)
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: PaymentStep.self) { step in
                    destinationView(for: step)
                }
        }
        .environment(\.dismissAll, { dismiss() })
        .task {
            PaywallAttributionStore.shared.set(context: context, source: source)
            Analytics.shared.track("paywall_shown", ["surface": "ios", "paywall_id": context.rawValue, "source": source])
            Analytics.shared.track("paywall_impression", ["platform": "ios", "paywall_id": context.rawValue, "source": source])
            if subscriptionManager.plans.isEmpty {
                await subscriptionManager.fetchPlans()
            }
            if selectedPlanCode == nil {
                selectedPlanCode = recommendedPlan?.code
            }
            // Whether to ask "why didn't you pay?" on exit (throttled by backend).
            if let rec = await subscriptionManager.fetchRecoveryOffer() {
                askSurvey = rec.askSurvey ?? false
            }
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro { dismiss() }
        }
        .sheet(isPresented: $showSurvey, onDismiss: { dismiss() }) {
            WhyNotPaySurvey(
                onPick: { reason in
                    surveyed = true
                    Task { await subscriptionManager.submitCancelSurvey(reason: reason, paywallID: context.rawValue) }
                    showSurvey = false
                },
                onSkip: { showSurvey = false }
            )
            .presentationDetents([.height(320)])
        }
    }

    /// Intercept close: ask why (once) if they're leaving without subscribing.
    private func handleDismiss() {
        if !subscriptionManager.isPro && askSurvey && !surveyed {
            showSurvey = true
        } else {
            dismiss()
        }
    }

    @ViewBuilder private var content: some View {
        ZStack(alignment: .bottom) {
            SalomTheme.Colors.bgMain.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerArt
                    headerCopy
                    if hasYearly { billingToggle }
                    planList
                    Spacer(minLength: 90)
                }
                // A vertical ScrollView does not always constrain its content's
                // cross axis. Yearly prices are wider than monthly prices and
                // could otherwise expand the entire paywall beyond the screen,
                // pushing labels and controls off-canvas.
                .padding(.horizontal, 22)
                .containerRelativeFrame(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 130)
            }

            stickyCTA
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { handleDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(SalomTheme.Colors.surfaceMuted)
                        .clipShape(Circle())
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Image-first value proof

    @ViewBuilder private var headerArt: some View {
        switch context.artStyle {
        case .beforeAfter, .imageCompare, .modelCompare:
            comparisonArt
        case .gallery, .toolkit:
            galleryArt
        case .presentation, .document, .secureDocument, .invoice, .fileAnalysis:
            documentArt
        case .quota, .score, .roadmap:
            progressArt
        case .voice:
            voiceArt
        case .recovery:
            recoveryArt
        case .proposal, .lesson, .student, .teacher, .business, .office:
            immersiveArt
        }
    }

    @ViewBuilder private var immersiveArt: some View {
        ZStack(alignment: proofAlignment) {
            CachedImage(imageUrl: context.spec.imageURL)
                .frame(maxWidth: .infinity)
                .frame(height: context.artStyle == .lesson ? 244 : 272)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.76)], startPoint: .center, endPoint: .bottom)
            proofCapsule
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: context.artStyle == .proposal ? 18 : 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: context.artStyle == .proposal ? 18 : 28, style: .continuous).strokeBorder(artAccent.opacity(0.45), lineWidth: 1))
    }

    @ViewBuilder private var documentArt: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [artAccent.opacity(0.22), SalomTheme.Colors.surfaceMuted], startPoint: .topLeading, endPoint: .bottomTrailing)
            CachedImage(
                imageUrl: context.spec.imageURL,
                contentMode: context.artStyle == .presentation ? .fill : .fit
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .padding(context.artStyle == .presentation ? 0 : 22)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            if context.artStyle == .secureDocument {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(artAccent, in: Circle())
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            proofCapsule.padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: context.artStyle == .invoice ? 252 : 272)
        .clipShape(RoundedRectangle(cornerRadius: context.artStyle == .invoice ? 16 : 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: context.artStyle == .invoice ? 16 : 28, style: .continuous).strokeBorder(artAccent.opacity(0.38), lineWidth: 1))
    }

    @ViewBuilder private var comparisonArt: some View {
        GeometryReader { proxy in
            let halfWidth = max((proxy.size.width - 1) / 2, 0)

            ZStack {
                HStack(spacing: 1) {
                    CachedImage(imageUrl: context.spec.imageURL)
                        .grayscale(1)
                        .opacity(0.72)
                        .frame(width: halfWidth, height: proxy.size.height)
                        .clipped()
                    CachedImage(imageUrl: context.spec.imageURL)
                        .frame(width: halfWidth, height: proxy.size.height)
                        .clipped()
                }
                Rectangle().fill(.white.opacity(0.72)).frame(width: 1, height: proxy.size.height)
                Image(systemName: context.artStyle == .modelCompare ? "sparkles" : "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(.black.opacity(0.48), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.38), lineWidth: 1))
                proofCapsule
                    .padding(16)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
            }
        }
        .frame(height: 276)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(artAccent.opacity(0.45), lineWidth: 1))
    }

    @ViewBuilder private var galleryArt: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 8
            let small = (proxy.size.width - gap) * 0.36
            HStack(spacing: gap) {
                CachedImage(imageUrl: context.spec.imageURL)
                    .frame(width: proxy.size.width - small - gap, height: 272)
                    .clipped()
                VStack(spacing: gap) {
                    CachedImage(imageUrl: context.spec.imageURL)
                        .frame(width: small, height: 132)
                        .clipped()
                    CachedImage(imageUrl: context.spec.imageURL)
                        .scaleEffect(1.12)
                        .frame(width: small, height: 132)
                        .clipped()
                }
            }
            .overlay(alignment: .bottomLeading) { proofCapsule.padding(16) }
        }
        .frame(height: 272)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(artAccent.opacity(0.4), lineWidth: 1))
    }

    @ViewBuilder private var progressArt: some View {
        ZStack(alignment: .bottomLeading) {
            CachedImage(imageUrl: context.spec.imageURL)
                .frame(maxWidth: .infinity)
                .frame(height: 272)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 10) {
                if context.artStyle == .quota {
                    GeometryReader { proxy in
                        Capsule().fill(.white.opacity(0.22))
                            .overlay(alignment: .leading) { Capsule().fill(artAccent).frame(width: proxy.size.width * 0.84) }
                    }
                    .frame(height: 9)
                } else {
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle().fill(index < 2 ? artAccent : .white.opacity(0.28)).frame(width: 10, height: 10)
                            if index < 2 { Capsule().fill(.white.opacity(0.45)).frame(maxWidth: .infinity).frame(height: 2) }
                        }
                    }
                }
                proofCapsule
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(artAccent.opacity(0.42), lineWidth: 1))
    }

    @ViewBuilder private var voiceArt: some View {
        ZStack {
            LinearGradient(colors: [artAccent.opacity(0.25), SalomTheme.Colors.surfaceMuted], startPoint: .topLeading, endPoint: .bottomTrailing)
            CachedImage(imageUrl: context.spec.imageURL)
                .frame(width: 208, height: 208)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: artAccent.opacity(0.34), radius: 30)
            Image(systemName: "waveform")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .padding(13)
                .background(.black.opacity(0.42), in: Circle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(18)
            proofCapsule
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 272)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(artAccent.opacity(0.5), lineWidth: 1))
    }

    @ViewBuilder private var recoveryArt: some View {
        ZStack(alignment: .bottomLeading) {
            CachedImage(imageUrl: context.spec.imageURL)
                .frame(maxWidth: .infinity)
                .frame(height: 196)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            HStack(spacing: 9) {
                Image(systemName: "clock.arrow.circlepath")
                Text(context.spec.proof)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.45), in: Capsule())
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(artAccent.opacity(0.45), lineWidth: 1))
    }

    private var proofCapsule: some View {
        Text(context.spec.proof)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.45), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
    }

    private var proofAlignment: Alignment {
        switch context.artStyle {
        case .teacher, .office: .bottomTrailing
        default: .bottomLeading
        }
    }

    private var artAccent: Color {
        switch context {
        case .accountingReport, .commercialOffer, .invoiceExport, .dtmScorePlan, .teacherFirstValue:
            Color(red: 0.08, green: 0.74, blue: 0.54)
        case .lessonPlan, .dtmDailyLimit, .paymentRecovery:
            Color(red: 0.98, green: 0.62, blue: 0.12)
        case .imageReferenceEdit, .imageGenerationLimit, .smartModelUpgrade:
            Color(red: 0.64, green: 0.35, blue: 0.96)
        case .voiceSessionLimit, .studentFirstValue, .general:
            SalomTheme.Colors.accentSecondary
        default:
            SalomTheme.Colors.accentPrimary
        }
    }

    @ViewBuilder private var headerCopy: some View {
        Text(context.spec.title)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(SalomTheme.Colors.textPrimary)
            .tracking(-0.7)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
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
                        Text(String.appLocalized(p == .yearly ? "Yillik" : "Oylik"))
                            .font(.system(size: 13.5, weight: .semibold))
                        if p == .yearly, maxSavingsPct > 0 {
                            Text("−\(maxSavingsPct)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(SalomTheme.Colors.onAccent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(SalomTheme.Colors.signal))
                        }
                    }
                    .foregroundColor(billingPeriod == p ? SalomTheme.Colors.textPrimary : SalomTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(billingPeriod == p ? SalomTheme.Colors.surface : Color.clear)
                    )
                    .contentShape(Rectangle())   // whole segment tappable, not just the text
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(SalomTheme.Colors.surfaceMuted))
    }

    @ViewBuilder private var planList: some View {
        if paidPlans.isEmpty {
            ProgressView()
                .tint(SalomTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            VStack(spacing: 10) {
                ForEach(displayedPlans, id: \.code) { plan in
                    PlanPriceRow(
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

    // MARK: - CTA

    @ViewBuilder private var stickyCTA: some View {
        if let selected = selectedPlan {
            VStack(spacing: 8) {
                Button {
                    HapticManager.shared.fire(.mediumImpact)
                    Analytics.shared.track("paywall_plan_clicked", ["plan": selected.code, "paywall_id": context.rawValue, "source": source])
                    Analytics.shared.track("paywall_plan_selected", ["plan": selected.code, "paywall_id": context.rawValue, "source": source])
                    path.append(PaymentStep.methodChoice(planCode: selected.code))
                } label: {
                    HStack(spacing: 6) {
                        Text(context.spec.cta)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        Text(formatPrice(selected.priceUzs))
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.horizontal, 18)
                    .foregroundColor(SalomTheme.Colors.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(SalomTheme.Colors.accentSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Text(String.appLocalized("Obuna avtomatik yangilanadi · to'lovlar qaytarilmaydi"))
                    .font(.system(size: 11))
                    .foregroundColor(SalomTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                Link(String.appLocalized("Foydalanish shartlari"), destination: URL(string: "https://salom-ai.uz/terms-of-service")!)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
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
        if let contextual = list.first(where: { $0.code.lowercased().contains(context.spec.recommendedTier) }) {
            return contextual
        }
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

// MARK: - Compact plan row with the full charged price

private struct PlanPriceRow: View {
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
                            selected ? SalomTheme.Colors.accentPrimary : SalomTheme.Colors.border,
                            lineWidth: selected ? 5 : 1
                        )
                        .frame(width: 18, height: 18)
                        .animation(.easeOut(duration: 0.15), value: selected)

                    // Plan name + period
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(localizedPlanTier(plan))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(SalomTheme.Colors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.86)
                            if isRecommended {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(SalomTheme.Colors.signal)
                                    .accessibilityLabel(String.appLocalized("Tavsiya"))
                            }
                        }
                        HStack(spacing: 6) {
                            Text(periodLabel)
                                .font(.system(size: 11.5))
                                .foregroundColor(SalomTheme.Colors.textTertiary)
                            if let s = savingsPct, s > 0 {
                                Text("−\(s)% tejang")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(SalomTheme.Colors.signal)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    // The actual charged amount is primary; no misleading daily framing.
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(formatPrice(plan.priceUzs))
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                            .tracking(-0.3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text(shortPeriodLabel)
                            .font(.system(size: 11))
                            .foregroundColor(SalomTheme.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? SalomTheme.Colors.surfaceMuted : SalomTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? SalomTheme.Colors.accentPrimary : SalomTheme.Colors.border,
                        lineWidth: selected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var periodLabel: String {
        let days = plan.durationDays ?? 30
        switch days {
        case 30:  return String.appLocalized("Oylik obuna")
        case 90:  return String.appLocalized("3 oylik obuna")
        case 365: return String.appLocalized("Yillik obuna")
        default:  return String(format: String.appLocalized("%lld kun"), days)
        }
    }

    private var shortPeriodLabel: String {
        let days = plan.durationDays ?? 30
        switch days {
        case 30:  return String.appLocalized("oy")
        case 90:  return String.appLocalized("3 oy")
        case 365: return String.appLocalized("yil")
        default:  return String(format: String.appLocalized("%lld kun"), days)
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

private func localizedPlanTier(_ plan: SubscriptionPlan) -> String {
    let code = plan.code.lowercased()
    let tier: String
    if code.contains("pro") {
        tier = String.appLocalized("Pro")
    } else if code.contains("standard") {
        tier = String.appLocalized("Standard")
    } else {
        tier = plan.name
    }
    return tier
}

private func formatPrice(_ uzs: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = " "
    return (f.string(from: NSNumber(value: uzs)) ?? "\(uzs)") + " UZS"
}


// MARK: - "Why didn't you pay?" exit survey

/// One-tap reason picker shown when a user closes the paywall without subscribing.
/// Records to /subscriptions/cancel-survey → admin Insights "Nega to'lamadi?".
struct WhyNotPaySurvey: View {
    let onPick: (String) -> Void
    let onSkip: () -> Void

    private let reasons: [(key: String, label: String)] = [
        ("no_card", "Kartam/balansim yo‘q"),
        ("expensive", "Qimmat tuyuldi"),
        ("later", "Keyinroq qilaman"),
        ("technical", "Texnik muammo"),
        ("other", "Boshqa sabab"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String.appLocalized("Ketishdan oldin — nega to‘lamadingiz?"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textPrimary)
                .padding(.top, 20)

            VStack(spacing: 8) {
                ForEach(reasons, id: \.key) { r in
                    Button { onPick(r.key) } label: {
                        HStack {
                            Text(String.appLocalized(r.label))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(SalomTheme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SalomTheme.Colors.surfaceMuted))
                    }
                }
            }

            Button(String.appLocalized("O‘tkazib yuborish"), action: onSkip)
                .font(.system(size: 13))
                .foregroundColor(SalomTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(SalomTheme.Colors.bgMain.ignoresSafeArea())
    }
}
