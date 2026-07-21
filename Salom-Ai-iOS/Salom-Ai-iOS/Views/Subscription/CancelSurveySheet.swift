//
//  CancelSurveySheet.swift
//  Salom-Ai-iOS
//
//  Cancellation / win-back reason survey. Shown when a user cancels their
//  subscription. Records WHY (reason keys identical to web: no_card / expensive
//  / later / technical / other) so iOS feeds the same admin "Nega to'lov
//  qilishmadi?" breakdown, then performs the actual cancel.
//

import SwiftUI

struct CancelSurveySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subs = SubscriptionManager.shared

    /// Called after the cancel completes (so the parent can refresh / dismiss).
    var onCancelled: () -> Void = {}

    @State private var selected: String?
    @State private var working = false

    // Reason keys MUST match web so the admin aggregates iOS + web together.
    private let reasons: [(key: String, label: String)] = [
        ("expensive", "Qimmat tuyuldi"),
        ("later", "Keyinroq qilmoqchiman"),
        ("no_card", "Kartam/balansim yo‘q edi"),
        ("technical", "Texnik muammo"),
        ("other", "Boshqa sabab"),
    ]

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nega obunani bekor qilmoqchisiz?")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                            .padding(.top, 4)
                        Text("Javobingiz xizmatni yaxshilashga yordam beradi.")
                            .font(.system(size: 13))
                            .foregroundColor(SalomTheme.Colors.textSecondary)

                        VStack(spacing: 10) {
                            ForEach(reasons, id: \.key) { r in
                                reasonRow(r.key, r.label)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }

                Spacer(minLength: 0)
                footer
            }
        }
        .interactiveDismissDisabled(working)
    }

    private var header: some View {
        HStack {
            Text("Obunani bekor qilish")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .salomGlassCircle(34)
            }
            .disabled(working)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }

    private func reasonRow(_ key: String, _ label: String) -> some View {
        Button {
            HapticManager.shared.fire(.selection)
            withAnimation(.easeOut(duration: 0.15)) { selected = key }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected == key ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(selected == key ? SalomTheme.Colors.accentPrimary : SalomTheme.Colors.textTertiary)
                Text(String.appLocalized(label))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .salomGlassCard(14, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task { await confirmCancel() }
            } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(.white).scaleEffect(0.85) }
                    Text(String.appLocalized(working ? "Bekor qilinmoqda…" : "Bekor qilishni tasdiqlash"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(SalomTheme.Colors.onAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(selected == nil ? 0.35 : 0.85))
                )
            }
            .buttonStyle(.plain)
            .disabled(selected == nil || working)

            Button {
                HapticManager.shared.fire(.selection)
                dismiss()
            } label: {
                Text("Obunamni saqlab qolaman")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }
            .disabled(working)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func confirmCancel() async {
        guard let reason = selected, !working else { return }
        working = true
        await subs.submitCancelSurvey(reason: reason)   // logs reason + analytics
        let ok = await subs.cancelSubscription()
        working = false
        HapticManager.shared.fire(ok ? .success : .error)
        onCancelled()
        dismiss()
    }
}
