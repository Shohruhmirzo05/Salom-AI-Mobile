//
//  ChatSideMenuView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case chat
    case apps
    case ish
    case realtime
    case presentations
    case referats
    case dtm
    case notifications
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .chat: return "Salom AI"
        case .apps: return "Ilovalar"
        case .ish: return "Ish — hujjatlar"
        case .realtime: return "Ovozli suhbat"
        case .presentations: return "Presentatsiyalar"
        case .referats: return "Referat / Insho"
        case .dtm: return "DTM testlar"
        case .notifications: return "Bildirishnomalar"
        case .settings: return "Sozlamalar"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .chat: return "O'zbekcha AI yordamchi"
        case .apps: return "Barcha vositalar — bir joyda"
        case .ish: return "Tijorat taklifi, shartnoma, hisobot…"
        case .realtime: return "Real vaqt ovozli AI"
        case .presentations: return "AI presentatsiya yaratish"
        case .referats: return "AI referat va insho"
        case .dtm: return "Moslashuvchan test tayyorgarlik"
        case .notifications: return "Xabarlar tarixi"
        case .settings: return "Ilova sozlamalari"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "sparkles"
        case .apps: return "square.grid.2x2.fill"
        case .ish: return "briefcase.fill"
        case .realtime: return "waveform.circle.fill"
        case .presentations: return "rectangle.on.rectangle.angled"
        case .referats: return "text.book.closed.fill"
        case .dtm: return "graduationcap.fill"
        case .notifications: return "bell"
        case .settings: return "gearshape"
        }
    }
}

struct ChatSideMenuView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var isOpen: Bool
    @State private var dragX: CGFloat = 0   // live drag-to-close translation
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
                    SalomTheme.Gradients.background
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        HeaderSection()
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        
                        Divider()
                            .background(SalomTheme.Colors.border)
                        
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
                .offset(x: isOpen ? dragX : -width)
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: isOpen)
                // Interactive drag-to-close: follow the finger leftward, then
                // close on a far-enough drag or a fast flick (ChatGPT-style).
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { v in if isOpen { dragX = min(0, v.translation.width) } }
                        .onEnded { v in
                            guard isOpen else { return }
                            let shouldClose = v.translation.width < -width * 0.33
                                || v.predictedEndTranslation.width < -width * 0.6
                            if shouldClose { HapticManager.shared.fire(.selection) }
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                if shouldClose { isOpen = false }
                                dragX = 0
                            }
                        }
                )

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
                    .frame(width: 36, height: 36)
                Text("Salom AI")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(SalomTheme.Colors.textPrimary)

                Spacer()

                // Notifications → a bell in the header (no list row).
                Button {
                    HapticManager.shared.fire(.lightImpact)
                    select(.notifications)
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                        .frame(width: 38, height: 38)
                        .salomGlassCircle(38)
                        .overlay(alignment: .topTrailing) {
                            if unreadNotificationCount > 0 {
                                Text(unreadNotificationCount > 99 ? "99+" : "\(unreadNotificationCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Capsule().fill(Color.red))
                                    .offset(x: 4, y: -2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                
                TextField(String.appLocalized("Xabarlarni qidirish"), text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .foregroundColor(SalomTheme.Colors.textPrimary)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .salomGlassPill()
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
                                .foregroundColor(SalomTheme.Colors.onAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium ga o'tish")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(SalomTheme.Colors.textPrimary)
                            Text("Cheklovsiz imkoniyatlar")
                                .font(.caption2)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SalomTheme.Colors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(SalomTheme.Colors.surfaceMuted)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            )
                    )
                }
                .fullScreenCover(isPresented: $showPaywall) {
                    PaywallSheet(context: .onboardingPersona, source: "ios_side_menu")
                }
            }
            
            // One entry to the Ilovalar hub — all features live there as a grid (no more
            // per-feature rows). Notifications = header bell; new-chat = the + button.
            MenuItemRow(
                icon3d: "rocket",
                title: MainSection.apps.title,
                subtitle: MainSection.apps.subtitle,
                isHighlighted: selectedSection == .apps
            ) {
                select(.apps)
            }

            // Re-open the "what can you do" value showcase.
            MenuItemRow(
                icon3d: "sparkles",
                title: "Nimalar qila olaman?",
                subtitle: "Salom AI imkoniyatlari",
                isHighlighted: false
            ) {
                withAnimation(.easeInOut(duration: 0.25)) { isOpen = false }
                NotificationCenter.default.post(name: .showValueShowcase, object: nil)
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
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Yangi chat")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(SalomTheme.Colors.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color(SalomTheme.Colors.accentPrimary), Color(SalomTheme.Colors.accentSecondary)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
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
                            .foregroundColor(SalomTheme.Colors.onAccent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(profileDisplayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.textPrimary)
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
            .salomGlassCard(14, interactive: true)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder func MenuItemRow(
        icon3d: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isHighlighted: Bool = false,
        badge: Int = 0,
        action: (() -> Void)? = nil
    ) -> some View {
        let row = HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Icon3DView(slug: icon3d, size: 34)
                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(SalomTheme.Colors.onAccent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 8, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
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
                                SalomTheme.Colors.surfaceMuted,
                                SalomTheme.Colors.surface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                SalomTheme.Colors.surface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(SalomTheme.Colors.border)
                    )
            )
        
        if let action {
            Button(action: action) {
                row
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                    .foregroundColor(SalomTheme.Colors.textPrimary)
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
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SalomTheme.Colors.surfaceMuted)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isActive
                    ? SalomTheme.Colors.surfaceMuted
                    : SalomTheme.Colors.surface
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isActive ? SalomTheme.Colors.accentPrimary.opacity(0.45) : SalomTheme.Colors.border)
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
                    .foregroundColor(SalomTheme.Colors.textPrimary)
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
                .fill(SalomTheme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SalomTheme.Colors.border)
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
