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
    
    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                contentView
                    .animation(.easeInOut(duration: 0.25), value: selectedSection)
            }
            .disabled(isMenuOpen)
            
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
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .chat:
            ChatView(viewModel: chatViewModel, isMenuOpen: $isMenuOpen)
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
            
        case .notifications:
            SectionScaffold(
                icon: MainSection.notifications.icon,
                title: "Bildirishnomalar",
                subtitle: "Xabarlar tarixi"
            ) {
                NotificationHistoryView()
            }
            
        case .settings:
            SectionScaffold(
                icon: MainSection.settings.icon,
                title: "Sozlamalar",
                subtitle: "Hisob va til sozlamalari"
            ) {
                SettingsScreen()
            }
        }
    }
    
    @ViewBuilder
    private func SectionScaffold<Content: View>(
        icon: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ShellHeader(icon: icon, title: title, subtitle: subtitle)
                ShellSeparator()
                content()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
    
    @ViewBuilder
    private func ShellHeader(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
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
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder func ShellSeparator() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
            .padding(.bottom, 4)
    }
}
