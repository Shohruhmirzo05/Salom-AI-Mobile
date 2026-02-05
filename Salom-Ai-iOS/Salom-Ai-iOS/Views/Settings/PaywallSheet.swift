//
//  PaywallSheet.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 28/01/25.
//

import SwiftUI

struct PaywallSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSafari = false
    @State private var paymentUrl: URL?
    
    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Image
                Image("premium_paywall_header")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.8),
                                Color.clear,
                                Color.black.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
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
                        
                        // Benefits List
                        VStack(spacing: 16) {
                            BenefitRow(icon: "message.fill", title: "Cheklovsiz xabarlar", subtitle: "Murosasiz muloqot")
                            BenefitRow(icon: "bolt.fill", title: "Tezkor javoblar", subtitle: "Navbatsiz xizmat")
                            BenefitRow(icon: "speaker.wave.3.fill", title: "Ovozli rejim", subtitle: "Jonli suhbatlar")
                            BenefitRow(icon: "sparkles", title: "Keyingi avlod modellari", subtitle: "Eng aqlli javoblar")
                        }
                        .padding(.vertical)
                        
                        // Action Button
                        if let proPlan = subscriptionManager.plans.first(where: { $0.priceUzs > 0 }) {
                            Button {
                                 HapticManager.shared.fire(.mediumImpact)
                                 Task {
                                     if let url = await subscriptionManager.subscribe(planCode: proPlan.code) {
                                         paymentUrl = url
                                         showSafari = true
                                     }
                                 }
                            } label: {
                                HStack {
                                    if subscriptionManager.isLoading {
                                        ProgressView().tint(.black)
                                    } else {
                                        Text("Pro ga o'tish - \(proPlan.priceUzs.formatted()) UZS/oy")
                                            .fontWeight(.bold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(SalomTheme.Colors.accentPrimary)
                                .foregroundColor(.black)
                                .cornerRadius(16)
                            }
                        } else {
                            ProgressView()
                                .tint(.white)
                        }
                        
                        Button("Keyinroq") {
                            HapticManager.shared.fire(.lightImpact)
                            dismiss()
                        }
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
        }
        .task {
            if subscriptionManager.plans.isEmpty {
                await subscriptionManager.fetchPlans()
            }
        }
        .fullScreenCover(isPresented: $showSafari) {
            if let url = paymentUrl {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: showSafari) { isPresented in
            // When user returns from payment, we automatically check status via lifecycle in App, 
            // but we can also trigger check here to be sure or dismiss if success.
            if !isPresented {
                Task {
                    await subscriptionManager.checkSubscriptionStatus()
                }
            }
        }
        .onChange(of: subscriptionManager.isPro) { isPro in
            if isPro {
                dismiss()
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
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
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
    }
}
