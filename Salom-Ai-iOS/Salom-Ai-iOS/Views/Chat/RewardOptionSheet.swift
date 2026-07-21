//
//  RewardOptionSheet.swift
//  Salom-Ai-iOS
//
//  Shown when a free-tier user hits their message limit. Offers a choice:
//  watch a rewarded ad for +1 message, or upgrade to a paid plan.
//

import SwiftUI

struct RewardOptionSheet: View {
    /// Whether a rewarded ad is loaded and ready to present.
    var adReady: Bool = true
    let onWatch: () -> Void
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(SalomTheme.Colors.textTertiary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Image(systemName: "gift.fill")
                .font(.system(size: 34))
                .foregroundStyle(SalomTheme.Colors.accentPrimary)
                .padding(.top, 4)

            VStack(spacing: 6) {
                Text("Limit tugadi")
                    .font(.headline)
                    .foregroundColor(SalomTheme.Colors.textPrimary)
                Text(adReady
                     ? "Bitta qisqa reklama ko'rib, yana 1 ta xabar yuboring."
                     : "Cheksiz xabarlar uchun Pro rejaga o'ting.")
                    .font(.subheadline)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                // Only offer the ad when one is actually ready to show.
                if adReady {
                    Button(action: onWatch) {
                        HStack {
                            Image(systemName: "play.rectangle.fill")
                            Text("Reklama ko'rib +1 xabar")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SalomTheme.Colors.accentPrimary)
                        .foregroundColor(SalomTheme.Colors.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button(action: onUpgrade) {
                    Text("Pro rejaga o'tish")
                        .fontWeight(adReady ? .medium : .semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        // Primary styling when it's the only action available.
                        .background(adReady ? SalomTheme.Colors.surfaceMuted : SalomTheme.Colors.accentPrimary)
                        .foregroundColor(adReady ? SalomTheme.Colors.textPrimary : SalomTheme.Colors.onAccent)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(adReady ? SalomTheme.Colors.border : Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SalomTheme.Gradients.background.ignoresSafeArea())
    }
}
