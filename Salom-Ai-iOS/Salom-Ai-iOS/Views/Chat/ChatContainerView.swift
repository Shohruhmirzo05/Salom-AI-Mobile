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
    // Native navigation stack for the Ilovalar hub → tools are PUSHED (real nav
    // bar + system back button), not swapped in place.
    @State private var appsPath: [MainSection] = []
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                contentView
                    .animation(.easeInOut(duration: 0.25), value: selectedSection)
            }
            .disabled(isMenuOpen)
            // Edge-swipe from the left edge opens the drawer in ANY section.
            // Skipped only where it would fight a view's own native back-swipe:
            // when an Ilovalar tool is pushed, or inside DTM's own nav stack.
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { v in
                        guard !isMenuOpen else { return }
                        if selectedSection == .apps && !appsPath.isEmpty { return }
                        if selectedSection == .dtm { return }
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
            NavigationStack(path: $appsPath) {
                IlovalarView(
                    onOpen: { section in
                        // Document tools push onto the hub's nav stack (native
                        // nav bar + back button). Voice/DTM/image own their own
                        // surfaces, so switch the whole section for those.
                        switch section {
                        case .ish, .presentations, .referats:
                            appsPath.append(section)
                        default:
                            withAnimation(.easeInOut(duration: 0.25)) { selectedSection = section }
                        }
                    },
                    onMenu: {
                        HapticManager.shared.fire(.selection)
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { isMenuOpen = true }
                    }
                )
                .navigationBarHidden(true)
                .navigationDestination(for: MainSection.self) { section in
                    pushedTool(section)
                }
            }

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
                subtitle: "Kasbiy hujjatlarni tayyorlang",
                onBack: { selectedSection = .apps }
            ) {
                WorkListView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .presentations:
            SectionScaffold(
                icon: MainSection.presentations.icon,
                title: "Presentatsiyalar",
                subtitle: "AI presentatsiya yaratish",
                onBack: { selectedSection = .apps }
            ) {
                PresentationsListView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .referats:
            SectionScaffold(
                icon: MainSection.referats.icon,
                title: "Referat / Insho",
                subtitle: "AI referat va insho",
                onBack: { selectedSection = .apps }
            ) {
                ReferatsListView()
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
    
    // A document tool pushed onto the Ilovalar nav stack: real navigation bar
    // (system back button returns to the hub) + a toolbar menu button for the
    // drawer. Transparent toolbar so the app's dark background shows through.
    @ViewBuilder
    private func pushedTool(_ section: MainSection) -> some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            Group {
                switch section {
                case .ish: WorkListView()
                case .presentations: PresentationsListView()
                case .referats: ReferatsListView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GlassIconButton(systemName: "line.3.horizontal", size: 36) {
                    HapticManager.shared.fire(.selection)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { isMenuOpen = true }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    @ViewBuilder
    private func SectionScaffold<Content: View, Trailing: View>(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ShellHeader(icon: icon, title: title, subtitle: subtitle, onBack: onBack, trailing: trailing)
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
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(spacing: 12) {
            // When a section is opened from the Ilovalar hub it shows a
            // back-to-hub chevron; otherwise the leading control opens the side
            // menu (matches the web's per-tool back button).
            Button {
                HapticManager.shared.fire(.selection)
                if let onBack {
                    withAnimation(.easeInOut(duration: 0.25)) { onBack() }
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                        isMenuOpen = true
                    }
                }
            } label: {
                Image(systemName: onBack != nil ? "chevron.left" : "line.3.horizontal")
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
