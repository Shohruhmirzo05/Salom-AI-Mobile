//
//  UpgradeNudge.swift
//  Salom-Ai-iOS
//
//  A non-blocking floating hint that appears just above the chat input bar
//  when a free-tier user is close to a resource limit (≥70% used). Taps the
//  hint → opens the paywall. Has a small ✕ to dismiss for the rest of the
//  session. Renders nothing for paid users or when no resource is close to
//  the cap, so it's a no-op for most launches.
//

import SwiftUI

struct UpgradeNudge: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var usage: UsageStatsResponse?
    @State private var dismissedThisSession = false
    @State private var showingPaywall = false

    /// 70% used → start hinting.
    private let threshold: Double = 0.7

    var body: some View {
        Group {
            if let payload = currentNudge {
                NudgeBubble(
                    text: payload.text,
                    onTap: { showingPaywall = true },
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            dismissedThisSession = true
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            await refresh()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallSheet()
        }
    }

    private func refresh() async {
        // Cheap call — APIClient caches at the HTTP level.
        do {
            let stats = try await APIClient.shared.request(.getUsageStats, decodeTo: UsageStatsResponse.self)
            await MainActor.run { usage = stats }
        } catch {
            // Best-effort — silently skip the nudge if we can't fetch.
        }
    }

    // MARK: - Logic

    private var isFreeTier: Bool {
        // Treat both no-active sub and "free"/"lite" as free for nudge purposes.
        if !(subscriptionManager.currentPlan?.active ?? false) { return true }
        let code = subscriptionManager.currentPlan?.plan ?? "free"
        return code == "free" || code == "lite"
    }

    private var currentNudge: NudgePayload? {
        guard !dismissedThisSession else { return nil }
        guard isFreeTier else { return nil }
        guard let usage else { return nil }

        // Candidates: limited resources where used / limit >= threshold.
        struct Slot { let label: String; let used: Int; let limit: Int }
        let slots: [Slot] = [
            .init(label: "Tezkor xabarlar", used: usage.usage.fastMessages, limit: usage.limits.fastMessages),
            .init(label: "Aqlli xabarlar", used: usage.usage.smartMessages, limit: usage.limits.smartMessages),
            .init(label: "Ovozli daqiqalar", used: usage.usage.voiceMinutes, limit: usage.limits.voiceMinutes),
            .init(label: "Rasm yaratishlar", used: usage.usage.imageGeneration, limit: usage.limits.imageGeneration),
        ]
        let close = slots
            .filter { $0.limit > 0 && Double($0.used) >= Double($0.limit) * threshold }
            .sorted { Double($0.used) / Double($0.limit) > Double($1.used) / Double($1.limit) }

        guard let top = close.first else { return nil }
        let remaining = max(0, top.limit - top.used)
        let text = remaining <= 0
            ? "\(top.label): limit tugadi. Pro rejaga o'tib davom eting."
            : "\(top.label): \(remaining) qoldi. Pro rejaga o'ting."
        return NudgePayload(text: text)
    }
}

private struct NudgePayload {
    let text: String
}

private struct NudgeBubble: View {
    let text: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(SalomTheme.Colors.accentPrimary.opacity(0.2))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("Rejani ko'rish →")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(SalomTheme.Colors.accentPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    SalomTheme.Colors.accentPrimary.opacity(0.15),
                    SalomTheme.Colors.accentPrimary.opacity(0.05)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SalomTheme.Colors.accentPrimary.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: SalomTheme.Colors.accentPrimary.opacity(0.15), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .padding(.horizontal, 12)
    }
}
