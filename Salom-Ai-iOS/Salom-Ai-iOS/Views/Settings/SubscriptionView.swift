import SwiftUI
import SafariServices
import Combine

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showSafari = false
    @State private var paymentUrl: URL?
    
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
        }
        .sheet(isPresented: $showSafari) {
            if let url = paymentUrl {
                SafariView(url: url)
            }
        }
        .onChange(of: showSafari) { isPresented in
            if !isPresented {
                // Refresh subscription when returning from Safari
                Task {
                    await subscriptionManager.checkSubscriptionStatus()
                }
            }
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
                    Task {
                        if let url = await subscriptionManager.subscribe(planCode: plan.code) {
                            paymentUrl = url
                            showSafari = true
                        }
                    }
                }
            } label: {
                HStack {
                    if subscriptionManager.isLoading {
                        // Ideal world: per-button loading state. 
                        // For now we check globally or simply don't block.
                        // Manager clears loading fast for fetch, but subscribe?
                        // Manager doesn't track specific subscribe loading yet in shared state except locally in view usually.
                        // We'll trust the flow or add local loading.
                         Text(plan.priceUzs > 0 ? "Tanlash (Click)" : "Bepul")
                            .fontWeight(.semibold)
                    } else {
                        if isCurrent {
                            Text("Faol")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        } else if plan.priceUzs == 0 {
                            Text("Bepul")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        } else {
                            Text("Tanlash (Click)")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
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

// Keep SafariView as it's used here and in PaywallSheet (if we don't move it)
// Ideally move to Utils but keeping here for compilation safety based on previous file context.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = false
        return SFSafariViewController(url: url, configuration: config)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
