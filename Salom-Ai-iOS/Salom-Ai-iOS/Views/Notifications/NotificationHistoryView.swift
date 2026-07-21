import SwiftUI
import Combine

struct NotificationModel: Identifiable, Codable {
    let id: Int
    let title: String
    let body: String
    let channel: String
    var isRead: Bool
    let createdAt: Date
}

struct UnreadCountResponse: Codable {
    let count: Int
}

@MainActor
final class NotificationViewModel: ObservableObject {
    @Published var notifications: [NotificationModel] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = true
    @Published var error: String?

    private let api = APIClient.shared

    func load() async {
        isLoading = notifications.isEmpty
        error = nil
        do {
            let items: [NotificationModel] = try await api.request(
                .notifications(limit: 50, offset: 0),
                decodeTo: [NotificationModel].self
            )
            notifications = items
            unreadCount = items.filter { !$0.isRead }.count
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func fetchUnreadCount() async {
        do {
            let resp: UnreadCountResponse = try await api.request(
                .unreadNotificationCount,
                decodeTo: UnreadCountResponse.self
            )
            unreadCount = resp.count
        } catch {
            // silent
        }
    }

    func markAsRead(_ notification: NotificationModel) async {
        guard !notification.isRead else { return }
        if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[idx].isRead = true
            unreadCount = max(0, unreadCount - 1)
        }
        do {
            let _: [String: Bool] = try await api.request(
                .markNotificationRead(id: notification.id),
                decodeTo: [String: Bool].self
            )
        } catch {
            // revert on failure
            if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[idx].isRead = false
                unreadCount += 1
            }
        }
    }

    func markAllAsRead() async {
        let previousUnread = notifications.filter { !$0.isRead }
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        unreadCount = 0
        do {
            let _: [String: Bool] = try await api.request(
                .markAllNotificationsRead,
                decodeTo: [String: Bool].self
            )
        } catch {
            // revert
            for item in previousUnread {
                if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
                    notifications[idx].isRead = false
                }
            }
            unreadCount = previousUnread.count
        }
    }
}

struct NotificationHistoryView: View {
    @StateObject private var viewModel = NotificationViewModel()

    var body: some View {
        ZStack {
            Color.clear

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: SalomTheme.Colors.accentPrimary))
            } else if let error = viewModel.error {
                ErrorStateView(message: error) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.notifications.isEmpty {
                EmptyStateView()
            } else {
                notificationList
            }
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var notificationList: some View {
        VStack(spacing: 0) {
            // Header bar with mark-all-read
            if viewModel.unreadCount > 0 {
                HStack {
                    Text("\(viewModel.unreadCount) ta o'qilmagan")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                    Spacer()
                    Button {
                        HapticManager.shared.fire(.lightImpact)
                        Task { await viewModel.markAllAsRead() }
                    } label: {
                        Text("Hammasini o'qish")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SalomTheme.Colors.accentPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.notifications) { notification in
                        NotificationRow(notification: notification) {
                            HapticManager.shared.fire(.selection)
                            Task { await viewModel.markAsRead(notification) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: NotificationModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(notification.isRead
                              ? SalomTheme.Colors.surfaceMuted
                              : SalomTheme.Colors.accentPrimary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(notification.isRead
                                         ? SalomTheme.Colors.textTertiary
                                         : SalomTheme.Colors.accentPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(notification.title)
                            .font(.system(size: 15, weight: notification.isRead ? .medium : .bold))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        if !notification.isRead {
                            Circle()
                                .fill(SalomTheme.Colors.accentPrimary)
                                .frame(width: 8, height: 8)
                                .padding(.top, 4)
                        }
                    }

                    Text(notification.body)
                        .font(.system(size: 14))
                        .foregroundColor(notification.isRead ? SalomTheme.Colors.textTertiary : SalomTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(relativeDate(notification.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(SalomTheme.Colors.textTertiary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(notification.isRead
                          ? SalomTheme.Colors.surface
                          : SalomTheme.Colors.controlFillActive)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(notification.isRead ? SalomTheme.Colors.separator : SalomTheme.Colors.accentPrimary.opacity(0.28))
            )
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch notification.channel {
        case "subscription": return "crown.fill"
        case "promotion": return "gift.fill"
        case "system": return "gearshape.fill"
        default: return "bell.fill"
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(SalomTheme.Colors.surfaceMuted)
                    .frame(width: 80, height: 80)
                Image(systemName: "bell.slash")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(SalomTheme.Colors.textTertiary)
            }
            Text("Bildirishnomalar yo'q")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)
            Text("Yangi xabarlar bu yerda ko'rinadi")
                .font(.system(size: 14))
                .foregroundColor(SalomTheme.Colors.textTertiary)
        }
    }
}

// MARK: - Error State

private struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(SalomTheme.Colors.textTertiary)
            Text("Xatolik yuz berdi")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textSecondary)
            Button(action: onRetry) {
                Text("Qayta urinish")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.accentPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(SalomTheme.Colors.accentPrimary.opacity(0.15))
                    )
            }
        }
    }
}

// MARK: - Relative Date Helper

private func relativeDate(_ date: Date) -> String {
    let now = Date()
    let seconds = now.timeIntervalSince(date)

    if seconds < 60 {
        return "Hozir"
    } else if seconds < 3600 {
        let mins = Int(seconds / 60)
        return "\(mins) daqiqa oldin"
    } else if seconds < 86400 {
        let hours = Int(seconds / 3600)
        return "\(hours) soat oldin"
    } else if seconds < 172800 {
        return "Kecha"
    } else if seconds < 604800 {
        let days = Int(seconds / 86400)
        return "\(days) kun oldin"
    } else {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "d MMM, HH:mm"
        return displayFormatter.string(from: date)
    }
}
