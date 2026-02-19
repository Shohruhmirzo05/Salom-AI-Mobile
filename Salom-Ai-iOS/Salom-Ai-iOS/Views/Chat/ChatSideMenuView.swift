//
//  ChatSideMenuView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case chat
//    case voice
    case realtime
    case notifications
    case settings
    
    var id: String { rawValue }
    
    var title: LocalizedStringKey {
        switch self {
        case .chat: return "Salom AI"
//        case .voice: return "Ovozli suhbat"
        case .realtime: return "Ovozli suhbat"
        case .notifications: return "Bildirishnomalar"
        case .settings: return "Sozlamalar"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .chat: return "O'zbekcha AI yordamchi"
//        case .voice: return "Tez orada"
        case .realtime: return "Real vaqt ovozli AI"
        case .notifications: return "Xabarlar tarixi"
        case .settings: return "Ilova sozlamalari"
        }
    }
    
    var icon: String {
        switch self {
        case .chat: return "sparkles"
//        case .voice: return "waveform.and.mic"
        case .realtime: return "waveform.circle.fill"
        case .notifications: return "bell"
        case .settings: return "gearshape"
        }
    }
}

struct ChatSideMenuView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isOpen: Bool
    @Binding var selectedSection: MainSection

    @AppStorage(AppStorageKeys.displayName) private var storedDisplayName: String = ""
    @AppStorage(AppStorageKeys.userEmail) private var storedEmail: String = ""

    private let session = SessionManager.shared

    private var profileDisplayName: String {
        if !storedDisplayName.isEmpty { return storedDisplayName }
        if !storedEmail.isEmpty { return storedEmail.components(separatedBy: "@").first ?? storedEmail }
        return "Foydalanuvchi"
    }

    private var profileInitials: String {
        let words = profileDisplayName.split(separator: " ")
        if words.count >= 2,
           let first = words[0].first,
           let second = words[1].first {
            return String(first).uppercased() + String(second).uppercased()
        }
        return String(profileDisplayName.prefix(2)).uppercased()
    }
    
    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.82, 380)
            let bottomInset = geo.safeAreaInsets.bottom
            
            HStack(spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(hex: "#0A0B22"),
                            Color(hex: "#090A1C")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        HeaderSection()
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        
                        Divider()
                            .background(Color.white.opacity(0.08))
                        
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 20) {
                                PrimaryItemsSection()
                                HistorySection()
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, max(bottomInset, 14) + 16)
                        }
                        .scrollIndicators(.never)
                        
                        Spacer(minLength: 0)
                        
                        ProfileSection()
                            .padding(.horizontal, 18)
                            .padding(.bottom, 12)
                    }
                }
                .frame(width: width, height: geo.size.height)
                .offset(x: isOpen ? 0 : -width)
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: isOpen)
                
                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(isOpen)
        .task(id: isOpen) {
            guard isOpen else { return }
            do {
                let resp: UnreadCountResponse = try await APIClient.shared.request(
                    .unreadNotificationCount,
                    decodeTo: UnreadCountResponse.self
                )
                unreadNotificationCount = resp.count
            } catch {}
        }
    }
    
    // MARK: - Sections
    @ViewBuilder func HeaderSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(.appIconTransparent)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                Text("Salom AI")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
            }
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                
                TextField(String(localized: "Xabarlarni qidirish"), text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var unreadNotificationCount: Int = 0
    
    @ViewBuilder func PrimaryItemsSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            
            
            // Pro Upgrade Banner
            if !subscriptionManager.isPro {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium ga o'tish")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("Cheklovsiz imkoniyatlar")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            )
                    )
                }
                .fullScreenCover(isPresented: $showPaywall) {
                    PaywallSheet()
                }
            }
            
            MenuItemRow(
                systemName: MainSection.chat.icon,
                title: MainSection.chat.title,
                subtitle: MainSection.chat.subtitle,
                isHighlighted: selectedSection == .chat
            ) {
                // Always start new chat when clicking "Salom AI"
                viewModel.startNewConversation()
                select(.chat)
            }
            
//            MenuItemRow(
//                systemName: MainSection.voice.icon,
//                title: MainSection.voice.title,
//                subtitle: MainSection.voice.subtitle,
//                isHighlighted: selectedSection == .voice
//            ) {
//                select(.voice)
//            }
            
            MenuItemRow(
                systemName: MainSection.realtime.icon,
                title: MainSection.realtime.title,
                subtitle: MainSection.realtime.subtitle,
                isHighlighted: selectedSection == .realtime
            ) {
                select(.realtime)
            }
            
            MenuItemRow(
                systemName: MainSection.notifications.icon,
                title: MainSection.notifications.title,
                subtitle: MainSection.notifications.subtitle,
                isHighlighted: selectedSection == .notifications,
                badge: unreadNotificationCount
            ) {
                select(.notifications)
            }
        }
    }
    
    @ViewBuilder func HistorySection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(viewModel.searchQuery.isEmpty ? "Yaqinda suhbatlar" : "Qidiruv natijalari")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                if viewModel.isLoadingConversations {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
                Spacer()
                Button {
                    HapticManager.shared.fire(.lightImpact)
                    viewModel.startNewConversation()
                    select(.chat)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(SalomTheme.Colors.accentPrimary)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
            }
            
            if viewModel.searchQuery.isEmpty {
                if viewModel.conversations.isEmpty {
                    Text("Hozircha chatlar yo'q. Yangi suhbatni boshlang.")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(viewModel.conversations) { conversation in
                        ConversationRow(conversation: conversation)
                    }
                }
            } else {
                if viewModel.searchResults.isEmpty {
                    Text("Hech narsa topilmadi")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                } else {
                    ForEach(viewModel.searchResults) { hit in
                        SearchHitRow(hit: hit)
                    }
                }
            }
        }
    }
    
    @ViewBuilder func ProfileSection() -> some View {
        Button {
            select(.settings)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: "#6366F1"))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(profileInitials)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(profileDisplayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("Sozlamalar")
                        .font(.caption2)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder func MenuItemRow(
        systemName: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isHighlighted: Bool = false,
        badge: Int = 0,
        action: (() -> Void)? = nil
    ) -> some View {
        let row = HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(
                        isHighlighted
                        ? SalomTheme.Colors.accentPrimary
                        : SalomTheme.Colors.textSecondary
                    )
                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 8, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }

            Spacer()
        }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isHighlighted
                        ? LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.06))
                    )
            )
        
        if let action {
            row
                .contentShape(Rectangle())
                .onTapGesture {
                    action()
                }
        } else {
            row
        }
    }
    
    @ViewBuilder func ConversationRow(conversation: ConversationSummary) -> some View {
        let isActive = viewModel.selectedConversation?.id == conversation.id
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title ?? "Chat #\(conversation.id)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let updated = conversation.updatedAt {
                    Text(updated.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                } else {
                    Text("Suhbat")
                        .font(.caption2)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
            }
            Spacer()
            Button {
                HapticManager.shared.fire(.lightImpact)
                viewModel.deleteConversation(conversation)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isActive
                    ? Color.white.opacity(0.06)
                    : Color.white.opacity(0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(isActive ? 0.12 : 0.05))
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.fire(.selection)
            viewModel.selectConversation(conversation)
            select(.chat)
        }
    }
    
    @ViewBuilder func SearchHitRow(hit: MessageSearchHit) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(SalomTheme.Colors.accentPrimary.opacity(0.18))
                .frame(width: 8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(hit.conversationTitle ?? "Chat #\(hit.conversationId ?? 0)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(hit.text ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.fire(.selection)
            viewModel.openSearchResult(hit)
            select(.chat)
        }
    }
    
    func select(_ section: MainSection) {
        HapticManager.shared.fire(.selection)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            selectedSection = section
            isOpen = false
        }
    }
}

#Preview {
    ChatSideMenuView(
        viewModel: ChatViewModel(),
        isOpen: .constant(true),
        selectedSection: .constant(.chat)
    )
}
