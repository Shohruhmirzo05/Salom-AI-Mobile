//
//  SettingsScreen.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI
import PhotosUI

struct SettingsScreen: View {
    @AppStorage(AppStorageKeys.phoneNumber)
    private var phoneNumber: String = ""

    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"

    @AppStorage(AppStorageKeys.displayName)
    private var storedDisplayName: String = ""

    @AppStorage(AppStorageKeys.userEmail)
    private var storedEmail: String = ""

    @AppStorage(AppStorageKeys.avatarUrl)
    private var storedAvatarUrl: String = ""

    private let session = SessionManager.shared

    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var currentPlanName: String = ""
    @State private var isPremium: Bool = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var avatarUploading = false

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        await MainActor.run { avatarUploading = true }
        do {
            let uploaded = try await APIClient.shared.request(
                .uploadFile(data: data, filename: "avatar.jpg"), decodeTo: FileUploadResponse.self)
            _ = try? await APIClient.shared.request(
                .updateProfile(language: nil, displayName: nil, avatarUrl: uploaded.url), decodeTo: OAuthUser.self)
            await MainActor.run { storedAvatarUrl = uploaded.url; avatarUploading = false }
        } catch {
            await MainActor.run { avatarUploading = false }
        }
    }

    // MARK: - Computed helpers

    private var profileName: String {
        if !storedDisplayName.isEmpty { return storedDisplayName }
        if !storedEmail.isEmpty {
            return storedEmail.components(separatedBy: "@").first ?? storedEmail
        }
        if !phoneNumber.isEmpty { return phoneNumber }
        return String(localized: "Foydalanuvchi")
    }

    private var profileSubtitle: String {
        if !storedEmail.isEmpty { return storedEmail }
        if !phoneNumber.isEmpty { return phoneNumber }
        return String(localized: "Ma'lumot yo'q")
    }

    private var profileInitials: String {
        let words = profileName.split(separator: " ")
        if words.count >= 2,
           let first = words[0].first,
           let second = words[1].first {
            return String(first).uppercased() + String(second).uppercased()
        }
        return String(profileName.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()

            FormContent()
                .padding(.top, 12)
        }
        .alert(String(localized: "Hisobni o'chirish"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Bekor qilish"), role: .cancel) { }
            Button(String(localized: "O'chirish"), role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Hisobingizni butunlay o'chirishni xohlaysizmi? Bu amal barcha suhbatlar, xabarlar va ma'lumotlaringizni butunlay o'chiradi. Bu amalni bekor qilib bo'lmaydi!")
        }
        .alert(String(localized: "Xatolik"), isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            if let error = deleteError { Text(error) }
        }
    }

    // MARK: - Layout

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

    // MARK: - Profile Card

    @ViewBuilder
    private func ProfileCard() -> some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                ZStack {
                    if !storedAvatarUrl.isEmpty, let url = URL(string: storedAvatarUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(SalomTheme.Gradients.accent)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    } else {
                        Circle().fill(SalomTheme.Gradients.accent).frame(width: 64, height: 64)
                        Text(profileInitials).font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                    }

                    if avatarUploading {
                        Circle().fill(Color.black.opacity(0.45)).frame(width: 64, height: 64)
                        ProgressView().tint(.white)
                    }

                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                        .frame(width: 22, height: 22)
                        .background(SalomTheme.Colors.accentPrimary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(SalomTheme.Colors.bgMain, lineWidth: 2))
                        .offset(x: 23, y: 23)
                }
                .frame(width: 64, height: 64)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(profileName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(profileSubtitle)
                    .font(.subheadline)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 24)
        .onChange(of: selectedAvatarItem) { item in
            if let item { Task { await uploadAvatar(item) } }
        }
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private func SubscriptionSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Obuna")
                .font(.footnote.weight(.semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)
                .padding(.bottom, 2)

            NavigationLink {
                SubscriptionView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isPremium ? Color.yellow.opacity(0.15) : Color.white.opacity(0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: isPremium ? "crown.fill" : "sparkles")
                            .font(.system(size: 18))
                            .foregroundColor(isPremium ? .yellow : .gray)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentPlanName.isEmpty ? String(localized: "Yuklanmoqda...") : currentPlanName)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                        Text(isPremium ? String(localized: "Faol obuna") : String(localized: "Bepul tarif"))
                            .font(.caption)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .padding(.vertical, 6)
            }
        }
        .glassCard(cornerRadius: 24)
        .task { await fetchSubscriptionStatus() }
    }

    // MARK: - Support Section

    @ViewBuilder
    private func SupportSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yordam")
                .font(.footnote.weight(.semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)
                .padding(.bottom, 2)

            NavigationLink {
                FeedbackView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fikr-mulohaza yuborish")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                        Text("Taklif va shikoyatlar")
                            .font(.caption)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .padding(.vertical, 6)
            }

            Link(destination: URL(string: "https://t.me/salomAIsupport_bot")!) {
                HStack(spacing: 12) {
                    Image("TelegramLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Telegram orqali yordam")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                        Text("Jonli qo'llab-quvvatlash — bir tap")
                            .font(.caption)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .padding(.vertical, 6)
            }
        }
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Language Section

    @ViewBuilder
    private func LanguageSection() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Til")
                .font(.footnote.weight(.semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)

            VStack(spacing: 8) {
                LanguageRow(code: "uz",      label: "Oʻzbekcha",  flag: "🇺🇿")
                LanguageRow(code: "uz-Cyrl", label: "Кириллча",   flag: "🇺🇿")
                LanguageRow(code: "ru",      label: "Русский",     flag: "🇷🇺")
                LanguageRow(code: "en",      label: "English",     flag: "🇬🇧")
            }
        }
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func LanguageRow(code: String, label: String, flag: String) -> some View {
        Button {
            if languageCode != code {
                languageCode = code
                Task { await updateLanguage(code: code) }
            }
        } label: {
            HStack(spacing: 12) {
                Text(flag)
                    .font(.title3)
                Text(label)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                Spacer()
                if languageCode == code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(SalomTheme.Colors.accentPrimary)
                        .font(.system(size: 20))
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Danger Zone

    @ViewBuilder
    private func DangerZone() -> some View {
        VStack(spacing: 0) {
            // Logout
            Button(role: .destructive) {
                HapticManager.shared.fire(.warning)
                session.logout()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                    Text("Chiqish")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .foregroundColor(.red)
                .padding(.vertical, 4)
            }

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.vertical, 10)

            // Delete Account
            Button(role: .destructive) {
                HapticManager.shared.fire(.warning)
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    if isDeleting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                    }
                    Text(isDeleting ? String(localized: "O'chirilmoqda...") : String(localized: "Hisobni o'chirish"))
                        .font(.footnote.weight(.medium))
                    Spacer()
                }
                .foregroundColor(.red.opacity(0.75))
            }
            .disabled(isDeleting)
        }
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Actions

    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        do {
            let _: StatusMessageResponse = try await APIClient.shared.request(
                .deleteAccount,
                decodeTo: StatusMessageResponse.self
            )
            await MainActor.run {
                HapticManager.shared.fire(.success)
                session.logout()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                deleteError = String(localized: "Hisobni o'chirishda xatolik yuz berdi: ") + error.localizedDescription
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
                    self.currentPlanName = String(localized: "Bepul")
                    self.isPremium = false
                }
            }
        } catch {
            await MainActor.run {
                self.currentPlanName = String(localized: "Bepul")
                self.isPremium = false
            }
        }
    }

    private func updateLanguage(code: String) async {
        do {
            let _: OAuthUser = try await APIClient.shared.request(
                .updateProfile(language: code, displayName: nil, avatarUrl: nil),
                decodeTo: OAuthUser.self
            )
        } catch {
            print("Failed to update language: \(error)")
        }
    }
}
