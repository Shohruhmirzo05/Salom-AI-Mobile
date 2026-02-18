import SwiftUI
import SafariServices
import Combine

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPlanForPayment: IdentifiablePlanCode?
    @State private var showCancelAlert = false
    @State private var isTogglingAutoRenew = false
    
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
                            .tint(.white)
                            .padding(.top, 40)
                    } else {
                        CurrentPlanSection()
                        AutoRenewSection()
                        PlansGrid()
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
                    .foregroundColor(.white)
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
        .alert("Obunani bekor qilish", isPresented: $showCancelAlert) {
            Button("Bekor qilish", role: .destructive) {
                Task {
                    let _ = await subscriptionManager.cancelSubscription()
                }
            }
            Button("Yo'q", role: .cancel) {}
        } message: {
            Text("Avtomatik yangilanish o'chiriladi. Obuna amal qilish muddati tugaguncha faol qoladi.")
        }
    }
    
    @ViewBuilder
    private func HeaderSection() -> some View {
        VStack(spacing: 8) {
            Text("Pro imkoniyatlar")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            Text("Cheklovsiz muloqot va ko'proq imkoniyatlar")
                .font(.subheadline)
                .foregroundColor(SalomTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
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
                            .foregroundColor(.white)
                        
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
                        .fill(Color.white.opacity(0.05))
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
                            .foregroundColor(.white)
                        
                        if let card = current.savedCard {
                            Text(card.maskedNumber)
                                .font(.caption)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isTogglingAutoRenew {
                        ProgressView().tint(.white)
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
                        .fill(Color.white.opacity(0.05))
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
                            .foregroundColor(.white)
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
                            .fill(Color.white.opacity(0.05))
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
                                .fill(Color.white.opacity(0.05))
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
        VStack(spacing: 16) {
            ForEach(subscriptionManager.plans) { plan in
                PlanCard(plan: plan)
            }
        }
    }
    
    @ViewBuilder
    private func PlanCard(plan: SubscriptionPlan) -> some View {
        let isCurrent = subscriptionManager.currentPlan?.plan == plan.code && subscriptionManager.currentPlan?.active == true
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(plan.name)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if plan.code == "pro" {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(plan.priceUzs.formatted()) UZS")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Text("/ oyiga")
                    .font(.caption)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }
            
            // Features list
            VStack(alignment: .leading, spacing: 8) {
                if let benefits = plan.benefits, !benefits.isEmpty {
                    ForEach(benefits.indices, id: \.self) { index in
                        let benefit = benefits[index]
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundColor(SalomTheme.Colors.accentPrimary)
                                .padding(.top, 2)
                            
                            Text(benefit[languageCode] ?? benefit["uz"] ?? "")
                                .font(.subheadline)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    Text("Imtiyozlar mavjud emas")
                        .font(.subheadline)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                        .italic()
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
                            .foregroundStyle(.white)
                    } else if plan.priceUzs == 0 {
                        Text("Bepul")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    } else {
                        Text("Tanlash")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isCurrent || plan.priceUzs == 0 ? Color.white.opacity(0.2) : SalomTheme.Colors.accentPrimary)
                )
                .foregroundColor((isCurrent || plan.priceUzs == 0) ? .white : .black)
            }
            .disabled(isCurrent || plan.priceUzs == 0)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
        )
    }
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
