import SwiftUI
import SafariServices
import Combine

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPlanForPayment: IdentifiablePlanCode?
    @State private var showCancelAlert = false
    @State private var isTogglingAutoRenew = false
    @State private var billingPeriod: BillingPeriod = .yearly   // prioritise yearly
    @State private var isRetrying = false
    @State private var retryError: String?
    
    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"
    
    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    HeaderSection()
                    
                    if subscriptionManager.isLoading && subscriptionManager.plans.isEmpty {
                        ProgressView()
                            .tint(SalomTheme.Colors.accentPrimary)
                            .padding(.top, 40)
                    } else {
                        RecoverySection()
                        CurrentPlanSection()
                        AutoRenewSection()
                        if subscriptionManager.currentPlan?.active != true {
                            PlansGrid()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Obunalar")
                    .font(.headline)
                    .foregroundColor(SalomTheme.Colors.textPrimary)
            }
        }
        .task {
            await subscriptionManager.fetchPlans()
            await subscriptionManager.checkSubscriptionStatus()
            await subscriptionManager.fetchSavedCards()
        }
        .fullScreenCover(item: $selectedPlanForPayment) { selection in
            NavigationStack {
                SubscriptionPaymentFlow(planCode: selection.code)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                selectedPlanForPayment = nil
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showCancelAlert) {
            CancelSurveySheet(onCancelled: {
                Task { await subscriptionManager.checkSubscriptionStatus() }
            })
            .presentationDetents([.medium, .large])
        }
    }
    
    @ViewBuilder
    private func HeaderSection() -> some View {
        VStack(spacing: 8) {
            Text(subscriptionManager.currentPlan?.active == true
                 ? L4(uz: "Obunangiz", kr: "Обунангиз", ru: "Ваша подписка", en: "Your subscription").t(languageCode)
                 : L4(uz: "Pro imkoniyatlar", kr: "Pro имкониятлар", ru: "Возможности Pro", en: "Pro benefits").t(languageCode))
                .font(.title2.weight(.bold))
                .foregroundColor(SalomTheme.Colors.textPrimary)
            
            Text(subscriptionManager.currentPlan?.active == true
                 ? L4(uz: "Reja, yangilanish va kartalarni boshqaring", kr: "Режа, янгиланиш ва карталарни бошқаринг", ru: "Управляйте планом, продлением и картами", en: "Manage your plan, renewal, and cards").t(languageCode)
                 : L4(uz: "Ko‘proq AI, rasm, ovoz va hujjatlar", kr: "Кўпроқ AI, расм, овоз ва ҳужжатлар", ru: "Больше ИИ, изображений, голоса и документов", en: "More AI, images, voice, and documents").t(languageCode))
                .font(.subheadline)
                .foregroundColor(SalomTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private func RecoverySection() -> some View {
        if let current = subscriptionManager.currentPlan, current.inRecovery == true {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text("To'lov amalga oshmadi").font(.headline).foregroundColor(SalomTheme.Colors.textPrimary)
                }
                Text("Obunangiz vaqtincha to'xtatildi. Kartangizni to'ldiring va qayta urinib ko'ring.")
                    .font(.subheadline).foregroundColor(SalomTheme.Colors.textSecondary)
                if let err = retryError {
                    Text(err).font(.caption).foregroundColor(.red)
                }
                Button {
                    Task {
                        isRetrying = true; retryError = nil
                        let (ok, msg) = await subscriptionManager.retryPayment()
                        isRetrying = false
                        if !ok { retryError = msg ?? "To'lov amalga oshmadi. Keyinroq urinib ko'ring." }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying { ProgressView().tint(SalomTheme.Colors.onMedia) }
                        else { Image(systemName: "creditcard.fill"); Text("Qayta urinib ko'rish").fontWeight(.semibold) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LinearGradient(colors: [Color(hex: "#33E1ED"), .purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(SalomTheme.Colors.onMedia).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isRetrying)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color.orange.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.orange.opacity(0.3)))
        }
    }

    @ViewBuilder
    private func CurrentPlanSection() -> some View {
        if let current = subscriptionManager.currentPlan, current.active {
            VStack(alignment: .leading, spacing: 12) {
                Text("Joriy reja")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(current.plan?.capitalized ?? "Noma'lum")
                            .font(.headline)
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                        
                        if let expires = current.expiresAt {
                            Text("Amal qilish muddati: \(expires.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundColor(SalomTheme.Colors.accentPrimary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SalomTheme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(SalomTheme.Colors.accentPrimary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    @ViewBuilder
    private func AutoRenewSection() -> some View {
        if let current = subscriptionManager.currentPlan, current.active {
            VStack(alignment: .leading, spacing: 12) {
                // Auto-renew toggle
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Avtomatik yangilanish")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                        
                        if let card = current.savedCard {
                            Text(card.maskedNumber)
                                .font(.caption)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isTogglingAutoRenew {
                        ProgressView().tint(SalomTheme.Colors.accentPrimary)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { current.autoRenew ?? false },
                            set: { newValue in
                                Task {
                                    isTogglingAutoRenew = true
                                    let cardId = current.savedCard?.id ?? subscriptionManager.savedCards.first?.id
                                    let _ = await subscriptionManager.toggleAutoRenew(cardId: cardId, enabled: newValue)
                                    isTogglingAutoRenew = false
                                }
                            }
                        ))
                        .labelsHidden()
                        .tint(SalomTheme.Colors.accentPrimary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SalomTheme.Colors.surface)
                )
                
                // Saved cards link
                NavigationLink {
                    SavedCardsView()
                } label: {
                    HStack {
                        Image(systemName: "creditcard")
                            .foregroundColor(SalomTheme.Colors.accentPrimary)
                        Text("Saqlangan kartalar")
                            .font(.subheadline)
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                        Spacer()
                        Text("\(subscriptionManager.savedCards.count)")
                            .font(.caption)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(SalomTheme.Colors.surface)
                    )
                }
                
                // Cancel subscription / expiry notice
                if current.autoRenew == true {
                    Button {
                        showCancelAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red.opacity(0.8))
                            Text("Obunani bekor qilish")
                                .font(.subheadline)
                                .foregroundColor(.red.opacity(0.8))
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(SalomTheme.Colors.surface)
                        )
                    }
                } else if let expires = current.expiresAt {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text("Obunangiz \(expires.formatted(date: .abbreviated, time: .omitted)) da tugaydi")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func PlansGrid() -> some View {
        let paid = subscriptionManager.plans.filter { $0.priceUzs > 0 && !$0.code.hasSuffix("_promo") }
        let hasYearly = paid.contains { PlanPeriodHelper.isYearly($0) }
        let displayed = paid.filter { PlanPeriodHelper.isYearly($0) == (billingPeriod == .yearly) }
        let maxSave = paid.compactMap { PlanPeriodHelper.savingsPct($0, in: paid) }.max() ?? 0
        VStack(spacing: 16) {
            if hasYearly {
                HStack(spacing: 4) {
                    ForEach([BillingPeriod.yearly, BillingPeriod.monthly], id: \.self) { p in
                        Button {
                            HapticManager.shared.fire(.lightImpact)
                            withAnimation(.easeOut(duration: 0.18)) { billingPeriod = p }
                        } label: {
                            HStack(spacing: 5) {
                                Text(String.appLocalized(p == .yearly ? "Yillik" : "Oylik"))
                                    .font(.system(size: 13.5, weight: .semibold))
                                if p == .yearly, maxSave > 0 {
                                    Text("−\(maxSave)%").font(.system(size: 10, weight: .bold)).foregroundColor(SalomTheme.Colors.onAccent)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Capsule().fill(SalomTheme.Colors.signal))
                                }
                            }
                            .foregroundColor(billingPeriod == p ? SalomTheme.Colors.textPrimary : SalomTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(billingPeriod == p ? SalomTheme.Colors.surface : Color.clear))
                            .contentShape(Rectangle())   // whole segment tappable, not just the text
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(SalomTheme.Colors.surfaceMuted))
            }
            ForEach(displayed) { plan in
                PlanCard(plan: plan, savingsPct: PlanPeriodHelper.savingsPct(plan, in: paid))
            }
        }
    }

    @ViewBuilder
    private func PlanCard(plan: SubscriptionPlan, savingsPct: Int? = nil) -> some View {
        let isCurrent = subscriptionManager.currentPlan?.plan == plan.code && subscriptionManager.currentPlan?.active == true
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(subscriptionPlanDisplayName(plan))
                    .font(.title3.weight(.bold))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
                
                Spacer()
                
                if plan.code == "pro" {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                let days = plan.durationDays ?? 30
                let perDay = Int((Double(plan.priceUzs) / Double(max(1, days))).rounded())
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(perDay.formatted()) so'm")
                        .font(.title.weight(.bold))
                        .foregroundColor(SalomTheme.Colors.textPrimary)
                    Text("/ kun")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                HStack(spacing: 6) {
                    Text("\(plan.priceUzs.formatted()) UZS / \(days >= 300 ? "yil" : "oy")")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                    if let s = savingsPct, s > 0 {
                        Text("−\(s)% tejang")
                            .font(.caption.weight(.bold))
                            .foregroundColor(SalomTheme.Colors.signal)
                    }
                }
            }
            
            // Feature comparison (✓/✗) — Pro gets all rows; lower tier shows premium rows as ✗.
            let isPro = plan.code.contains("pro")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(planCompareFeatures) { f in
                    let included = isPro || !f.proOnly
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: included ? "checkmark" : "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundColor(included ? (isPro ? .yellow : SalomTheme.Colors.accentPrimary) : SalomTheme.Colors.textTertiary)
                            .padding(.top, 2)

                        Text(String.appLocalized(f.label))
                            .font(.subheadline)
                            .foregroundColor(included ? SalomTheme.Colors.textSecondary : SalomTheme.Colors.textTertiary)
                            .strikethrough(!included, color: SalomTheme.Colors.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 8)
            
            Button {
                HapticManager.shared.fire(.mediumImpact)
                if plan.priceUzs > 0 {
                    selectedPlanForPayment = IdentifiablePlanCode(code: plan.code)
                }
            } label: {
                HStack {
                    if isCurrent {
                        Text("Faol")
                            .fontWeight(.semibold)
                            .foregroundStyle(SalomTheme.Colors.textSecondary)
                    } else if plan.priceUzs == 0 {
                        Text("Bepul")
                            .fontWeight(.semibold)
                            .foregroundStyle(SalomTheme.Colors.textSecondary)
                    } else {
                        Text("Tanlash")
                            .fontWeight(.semibold)
                            .foregroundStyle(SalomTheme.Colors.onAccent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCurrent || plan.priceUzs == 0 ? SalomTheme.Colors.surfaceMuted : SalomTheme.Colors.accentPrimary)
                )
                .foregroundColor((isCurrent || plan.priceUzs == 0) ? SalomTheme.Colors.textSecondary : SalomTheme.Colors.onAccent)
            }
            .disabled(isCurrent || plan.priceUzs == 0)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(SalomTheme.Colors.surface)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(SalomTheme.Colors.border, lineWidth: 1))
        )
    }
}

private func subscriptionPlanDisplayName(_ plan: SubscriptionPlan) -> String {
    let code = plan.code.lowercased()
    if code.contains("pro") { return String.appLocalized("Pro") }
    if code.contains("standard") { return String.appLocalized("Standard") }
    if code.contains("free") || code.contains("lite") { return String.appLocalized("Bepul") }
    return plan.name
}

struct IdentifiablePlanCode: Identifiable {
    let id = UUID()
    let code: String
}

// Keep SafariView for backward compatibility
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = false
        return SFSafariViewController(url: url, configuration: config)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
