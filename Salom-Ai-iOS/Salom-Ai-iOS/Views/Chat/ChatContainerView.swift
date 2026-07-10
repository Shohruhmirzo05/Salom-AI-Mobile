//
//  ChatContainerView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

struct ChatContainerView: View {
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var isMenuOpen = false
    @State private var selectedSection: MainSection = .chat
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                contentView
                    .animation(.easeInOut(duration: 0.25), value: selectedSection)
            }
            .disabled(isMenuOpen)
            // Edge-swipe from the left to open the drawer (chat root only, so it
            // doesn't fight pushed views' native back-swipe).
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { v in
                        guard selectedSection == .chat, !isMenuOpen else { return }
                        if v.startLocation.x < 28, v.translation.width > 70, abs(v.translation.height) < 60 {
                            HapticManager.shared.fire(.selection)
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { isMenuOpen = true }
                        }
                    }
            )
            
            if isMenuOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        HapticManager.shared.fire(.selection)
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            isMenuOpen = false
                        }
                    }
            }
            
            ChatSideMenuView(
                viewModel: chatViewModel,
                isOpen: $isMenuOpen,
                selectedSection: $selectedSection
            )
            .zIndex(2)
        }
        .onAppear { Analytics.shared.track("screen_view", ["path": "/\(selectedSection.rawValue)"]) }
        .onChange(of: selectedSection) { _, newValue in
            Analytics.shared.track("screen_view", ["path": "/\(newValue.rawValue)"])
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSection)) { note in
            // Value showcase (or any deep link) → switch section + close the menu.
            if let raw = note.userInfo?["section"] as? String,
               let section = MainSection(rawValue: raw) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    selectedSection = section
                    isMenuOpen = false
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .chat:
            ChatView(viewModel: chatViewModel, isMenuOpen: $isMenuOpen)
                .navigationBarHidden(true)

        case .apps:
            IlovalarView(
                onOpen: { section in
                    HapticManager.shared.fire(.lightImpact)
                    withAnimation(.easeInOut(duration: 0.25)) { selectedSection = section }
                },
                onMenu: {
                    HapticManager.shared.fire(.selection)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { isMenuOpen = true }
                }
            )
            .navigationBarHidden(true)

            //        case .voice:
            //            SectionScaffold(
            //                icon: MainSection.voice.icon,
            //                title: "Ovozli suhbat",
            //                subtitle: ""
            //            ) {
            //                VoiceView()
            //            }
            
        case .realtime:
            RealtimeVoiceView(onDismiss: {
                withAnimation {
                    selectedSection = .chat
                }
            })
            .navigationBarHidden(true)
            
        case .ish:
            SectionScaffold(
                icon: MainSection.ish.icon,
                title: "Ish — hujjatlar",
                subtitle: "Kasbiy hujjatlarni tayyorlang"
            ) {
                WorkListView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .presentations:
            SectionScaffold(
                icon: MainSection.presentations.icon,
                title: "Presentatsiyalar",
                subtitle: "AI presentatsiya yaratish"
            ) {
                PresentationsListView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .dtm:
            // DtmView owns its NavigationStack (native back) + a toolbar menu
            // button that opens the side menu.
            DtmView(onMenu: {
                HapticManager.shared.fire(.selection)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { isMenuOpen = true }
            })

        case .notifications:
            SectionScaffold(
                icon: MainSection.notifications.icon,
                title: "Bildirishnomalar",
                subtitle: "Xabarlar tarixi"
            ) {
                NotificationHistoryView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
        case .settings:
            SectionScaffold(
                icon: MainSection.settings.icon,
                title: "Sozlamalar",
                subtitle: "Hisob va til sozlamalari",
                trailing: { LanguageMenuButton() }
            ) {
                SettingsScreen()
            }
        }
    }
    
    @ViewBuilder
    private func SectionScaffold<Content: View, Trailing: View>(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ShellHeader(icon: icon, title: title, subtitle: subtitle, trailing: trailing)
                ShellSeparator()
                content()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }

    @ViewBuilder
    private func ShellHeader<Trailing: View>(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                HapticManager.shared.fire(.selection)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    isMenuOpen = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .salomGlassCircle(40)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.accentPrimary)
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Language Menu Button (shown in Settings header)

    @ViewBuilder
    private func LanguageMenuButton() -> some View {
        let currentFlag = languageFlag(for: languageCode)
        Menu {
            Button {
                setLanguage("uz")
            } label: {
                Label("🇺🇿 Oʻzbekcha", systemImage: languageCode == "uz" ? "checkmark" : "")
            }
            Button {
                setLanguage("uz-Cyrl")
            } label: {
                Label("🇺🇿 Кириллча", systemImage: languageCode == "uz-Cyrl" ? "checkmark" : "")
            }
            Button {
                setLanguage("ru")
            } label: {
                Label("🇷🇺 Русский", systemImage: languageCode == "ru" ? "checkmark" : "")
            }
            Button {
                setLanguage("en")
            } label: {
                Label("🇬🇧 English", systemImage: languageCode == "en" ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: 4) {
                Text(currentFlag)
                    .font(.system(size: 18))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    private func languageFlag(for code: String) -> String {
        switch code {
        case "ru":      return "🇷🇺"
        case "en":      return "🇬🇧"
        default:        return "🇺🇿"
        }
    }

    private func setLanguage(_ code: String) {
        languageCode = code
        Task {
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
    
    @ViewBuilder func ShellSeparator() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
            .padding(.bottom, 4)
    }
}
