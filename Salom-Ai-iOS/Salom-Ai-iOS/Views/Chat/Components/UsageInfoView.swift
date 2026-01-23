//
//  UsageInfoView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 24/11/25.
//

import SwiftUI
import Combine

struct UsageInfoView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = UsageInfoViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                SalomTheme.Colors.bgMain.ignoresSafeArea()
                
                if viewModel.isLoading {
//                    ProgressView()
//                        .tint(.white)
                    LoadingMessagesPlaceholder()
                } else if let data = viewModel.data {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Plan Card
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(data.plan.name)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(data.plan.priceUzs?.formatted() ?? "0") so'm/oy")
                                        .font(.subheadline)
                                        .foregroundColor(SalomTheme.Colors.accentPrimary)
                                }
                                
                                Text("Yangilanadi: \(formatDate(data.resetDate ?? ""))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            
                            // Limits
                            VStack(spacing: 20) {
                                // Fast Models
                                if !viewModel.fastModels.isEmpty {
                                    SectionHeader(title: "Tezkor Modellar")
                                    ForEach(viewModel.fastModels) { model in
                                        UsageRow(
                                            icon: "bolt.fill",
                                            title: model.name,
                                            used: model.usage ?? 0,
                                            limit: model.limit ?? -1
                                        )
                                    }
                                }
                                
                                // Smart Models
                                if !viewModel.smartModels.isEmpty {
                                    SectionHeader(title: "Aqlli Modellar")
                                    ForEach(viewModel.smartModels) { model in
                                        UsageRow(
                                            icon: "brain.head.profile",
                                            title: model.name,
                                            used: model.usage ?? 0,
                                            limit: model.limit ?? -1
                                        )
                                    }
                                }
                                
                                // Super Smart Models
                                if !viewModel.superSmartModels.isEmpty {
                                    SectionHeader(title: "Super Aqlli Modellar")
                                    ForEach(viewModel.superSmartModels) { model in
                                        UsageRow(
                                            icon: "sparkles",
                                            title: model.name,
                                            used: model.usage ?? 0,
                                            limit: model.limit ?? -1
                                        )
                                    }
                                }
                                
                                SectionHeader(title: "Boshqa")
                                UsageRow(
                                    icon: "photo",
                                    title: "Rasm yaratish",
                                    used: data.usage.imageGeneration,
                                    limit: data.limits.imageGeneration
                                )
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Obuna ma'lumotlari")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Yopish") { dismiss() }
                }
            }
        }
        .onAppear { viewModel.loadData() }
    }
    
    func formatDate(_ dateString: String) -> String {
        return dateString.prefix(10).description
    }
    
    @ViewBuilder func SectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct UsageRow: View {
    let icon: String
    let title: String
    let used: Int
    let limit: Int
    
    var percentage: Double {
        guard limit > 0 else { return 0 }
        return min(Double(used) / Double(limit), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(SalomTheme.Colors.accentPrimary)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(used)/\(limit == -1 ? "∞" : "\(limit)")")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [SalomTheme.Colors.accentPrimary, SalomTheme.Colors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

class UsageInfoViewModel: ObservableObject {
    @Published var data: UsageStatsResponse?
    @Published var models: [AIModel] = []
    @Published var isLoading = false
    
    func loadData() {
        isLoading = true
        Task {
            do {
                async let usageTask = APIClient.shared.request(.getUsageStats, decodeTo: UsageStatsResponse.self)
                async let modelsTask = APIClient.shared.request(.getModels, decodeTo: [AIModel].self)
                
                let (usage, modelsList) = try await (usageTask, modelsTask)
                
                await MainActor.run {
                    self.data = usage
                    self.models = modelsList
                    self.isLoading = false
                }
            } catch {
                print("Failed to load usage/models: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    func getModelsTitle(for tier: String, defaultName: String) -> String {
        let tierModels = models.filter { $0.tier == tier }
        if tierModels.isEmpty {
            return defaultName
        }
        let names = tierModels.map { $0.name }.joined(separator: ", ")
        return "\(defaultName) (\(names))"
    }
    
    var fastModels: [AIModel] { models.filter { $0.tier == "fast" } }
    var smartModels: [AIModel] { models.filter { $0.tier == "smart" } }
    var superSmartModels: [AIModel] { models.filter { $0.tier == "super_smart" } }
}
