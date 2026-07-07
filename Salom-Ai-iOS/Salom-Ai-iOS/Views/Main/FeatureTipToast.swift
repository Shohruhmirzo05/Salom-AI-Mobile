//
//  FeatureTipToast.swift
//  Salom-Ai-iOS
//
//  A small, tasteful "did you know?" tip that surfaces a feature the user may not
//  know about. Throttled to ONCE PER DAY, shown only to non-Pro users, auto-
//  dismisses, and tapping it opens the full value showcase. Non-intrusive nudge
//  toward feature discovery + Pro.
//

import SwiftUI

struct FeatureTip: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let text: String
}

private let FEATURE_TIPS: [FeatureTip] = [
    .init(icon: "rectangle.on.rectangle.angled.fill", tint: .green, text: "Salom AI to‘liq taqdimot (PPTX/PDF) yasaydi — menyudan Presentatsiyalar."),
    .init(icon: "graduationcap.fill", tint: .indigo, text: "DTM’ga tayyorlaning — fanlar bo‘yicha testlar menyuda."),
    .init(icon: "photo.fill", tint: .purple, text: "Chatda “rasm chiz …” deb yozing — Salom AI rasm yaratadi."),
    .init(icon: "doc.text.fill", tint: .orange, text: "Referat yoki insho kerakmi? Chatda so‘rang — tayyor hujjat oling."),
    .init(icon: "waveform", tint: .pink, text: "Ovozli suhbat — gapiring, javobni eshiting. Menyuda mavjud."),
]

struct FeatureTipToast: ViewModifier {
    /// Only nudge non-paying users.
    let isPro: Bool
    @AppStorage("tip_last_day") private var tipLastDay: String = ""
    @State private var tip: FeatureTip?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let tip {
                    banner(tip)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: tip?.id)
            .task { await maybeShow() }
    }

    @ViewBuilder private func banner(_ tip: FeatureTip) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tip.tint.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: tip.icon).font(.system(size: 16, weight: .semibold)).foregroundColor(tip.tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Bilasizmi?").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.5))
                Text(tip.text).font(.system(size: 12.5, weight: .medium)).foregroundColor(.white).lineLimit(2)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
        .onTapGesture {
            dismiss()
            NotificationCenter.default.post(name: .showValueShowcase, object: nil)
        }
        .gesture(DragGesture(minimumDistance: 8).onEnded { v in if v.translation.height < -20 { dismiss() } })
    }

    private func dismiss() { withAnimation { tip = nil } }

    private func maybeShow() async {
        guard !isPro else { return }
        let today = Self.dayKey()
        guard tipLastDay != today else { return }
        // Wait a bit so it doesn't collide with splash / first-run showcase.
        try? await Task.sleep(nanoseconds: 7_000_000_000)
        guard tip == nil else { return }
        tipLastDay = today
        let picked = FEATURE_TIPS.randomElement()
        await MainActor.run { withAnimation { tip = picked } }
        // Auto-dismiss after a few seconds.
        try? await Task.sleep(nanoseconds: 6_000_000_000)
        await MainActor.run { if tip?.id == picked?.id { dismiss() } }
    }

    private static func dayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}

extension View {
    /// Shows a once-a-day feature tip (non-Pro users) that opens the value showcase.
    func featureTipToast(isPro: Bool) -> some View { modifier(FeatureTipToast(isPro: isPro)) }
}
