//
//  SettingsScreen.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

struct SettingsScreen: View {
    @AppStorage(AppStorageKeys.phoneNumber)
    private var phoneNumber: String = ""

    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"
    
    private let session = SessionManager.shared
    
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var currentPlanName: String = "Yuklanmoqda..."
    @State private var isPremium: Bool = false

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()

            FormContent()
                .padding(.top, 12)
        }
        .alert(deleteAccountTitle, isPresented: $showDeleteConfirmation) {
            Button(cancelButton, role: .cancel) { }
            Button(deleteButton, role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text(deleteAccountMessage)
        }
        .alert(errorTitle, isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button(okButton, role: .cancel) {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
    }
    
    // MARK: - Localized Strings
    
    private var deleteAccountTitle: LocalizedStringKey {
        "Hisobni o'chirish"
    }
    
    private var deleteAccountMessage: LocalizedStringKey {
        "Hisobingizni butunlay o'chirishni xohlaysizmi? Bu amal barcha suhbatlar, xabarlar va ma'lumotlaringizni butunlay o'chiradi. Bu amalni bekor qilib bo'lmaydi!"
    }
    
    private var deleteButton: LocalizedStringKey {
        "O'chirish"
    }
    
    private var cancelButton: LocalizedStringKey {
        "Bekor qilish"
    }
    
    private var errorTitle: LocalizedStringKey {
        "Xatolik"
    }
    
    private var okButton: LocalizedStringKey {
        "OK"
    }
    
    private var deleteAccountButtonText: LocalizedStringKey {
        "Hisobni o'chirish"
    }
    
    private var deletingText: LocalizedStringKey {
        "O'chirilmoqda..."
    }

    // MARK: - Components

    @ViewBuilder
    private func FormContent() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfileCard()

                SubscriptionSection()

                SupportSection()

                LanguageSection()

                DangerZone()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func ProfileCard() -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(SalomTheme.Gradients.accent)
                    .frame(width: 54, height: 54)
                Text(initials)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                if !phoneNumber.isEmpty {
                    Text(phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                } else {
                    Text("Telefon raqam aniqlanmagan")
                        .font(.subheadline)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func SubscriptionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Obuna")
                .font(.footnote.weight(.semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)
            
            NavigationLink {
                SubscriptionView()
            } label: {
                HStack {
                    if isPremium {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                    } else {
                        Image(systemName: "sparkles")
                            .foregroundColor(.gray)
                    }
                    Text(currentPlanName)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
            }
        }
        .glassCard(cornerRadius: 24)
        .task {
            await fetchSubscriptionStatus()
        }
    }

    @ViewBuilder
    private func SupportSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yordam")
                .font(.footnote.weight(.semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)
            
            NavigationLink {
                FeedbackView()
            } label: {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.blue)
                    Text("Fikr-mulohaza yuborish")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
            }
        }
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func LanguageSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Til")
                .font(.footnote.weight(.semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)

            Picker("Til", selection: $languageCode) {
                Text("Oʻzbekcha").tag("uz")
                Text("Ruscha").tag("ru")
                Text("Inglizcha").tag("en")
            }
            .pickerStyle(.segmented)
            .onChange(of: languageCode) { newCode in
                Task {
                    await updateLanguage(code: newCode)
                }
            }
        }
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func DangerZone() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kirish maʼlumotlari")
                .font(.footnote.weight(.semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)

            Button(role: .destructive) {
                HapticManager.shared.fire(.warning)
                session.logout()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                    Text("Chiqish")
                        .font(.body.weight(.semibold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
            }
            
            Button(role: .destructive) {
                HapticManager.shared.fire(.warning)
                showDeleteConfirmation = true
            } label: {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(0.8)
                    }
                    Text(isDeleting ? deletingText : deleteAccountButtonText)
                        .font(.footnote)
                }
                .foregroundColor(.red.opacity(0.8))
                .padding(.vertical, 8)
            }
            .disabled(isDeleting)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Helpers

    private var displayName: String {
        if !phoneNumber.isEmpty {
            return "Salom foydalanuvchi"
        }
        return "Mehmon"
    }

    private var initials: String {
        if !phoneNumber.isEmpty {
            return "SA"
        }
        return "G"
    }
    
    // MARK: - Actions
    
    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        
        do {
            print("🗑️ [Settings] Starting account deletion...")
            
            // Call the delete account API
            let _: StatusMessageResponse = try await APIClient.shared.request(
                .deleteAccount,
                decodeTo: StatusMessageResponse.self
            )
            
            print("✅ [Settings] Account deleted successfully")
            
            // Logout and clear all data
            await MainActor.run {
                HapticManager.shared.fire(.success)
                session.logout()
            }
            
        } catch {
            print("❌ [Settings] Failed to delete account: \(error)")
            await MainActor.run {
                isDeleting = false
                deleteError = "Hisobni o'chirishda xatolik yuz berdi: \(error.localizedDescription)"
                HapticManager.shared.fire(.error)
            }
        }
    }
    
    private func fetchSubscriptionStatus() async {
        do {
            let sub = try await APIClient.shared.request(.currentSubscription, decodeTo: CurrentSubscriptionResponse.self)
            await MainActor.run {
                if sub.active, let plan = sub.plan {
                    self.currentPlanName = plan.capitalized
                    self.isPremium = true
                } else {
                    self.currentPlanName = "Bepul"
                    self.isPremium = false
                }
            }
        } catch {
            print("Failed to fetch subscription: \(error)")
            await MainActor.run {
                self.currentPlanName = "Bepul"
                self.isPremium = false
            }
        }
    }
    
    private func updateLanguage(code: String) async {
        do {
            let _: OAuthUser = try await APIClient.shared.request(
                .updateProfile(language: code, displayName: nil),
                decodeTo: OAuthUser.self
            )
        } catch {
            print("Failed to update language: \(error)")
        }
    }
}

// MARK: - Response Model
//
//struct StatusMessageResponse: Codable {
//    let ok: Bool
//    let message: String?
//    let detail: String?
//}
