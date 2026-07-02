//
//  PaymentToast.swift
//  Salom-Ai-iOS
//
//  Top banner shown after the user returns from a Payme / Click checkout (via the
//  salomai:// deep link, or as a scenePhase fallback). It is the single, root-level
//  confirmation surface — see `ContentView.paymentToast(_:)` and
//  `SubscriptionManager.paymentToast`.
//

import SwiftUI

// MARK: - Model

/// The outcome of a redirect checkout, mapped from the deep-link `status` param
/// (`paid` / `failed` / `cancelled`) or inferred from a subscription refresh.
enum PaymentToastKind: Equatable {
    case success
    case failed
    case cancelled

    /// Map the web result page's `status` query value onto a toast kind.
    init?(status: String?) {
        switch status?.lowercased() {
        case "paid", "success": self = .success
        case "failed", "error":  self = .failed
        case "cancelled", "canceled", "expired": self = .cancelled
        default: return nil
        }
    }

    var icon: String {
        switch self {
        case .success:   return "checkmark.circle.fill"
        case .failed:    return "xmark.circle.fill"
        case .cancelled: return "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success:   return Color(hex: "#34D399") // emerald
        case .failed:    return Color(hex: "#F97373") // red
        case .cancelled: return Color(hex: "#FBBF24") // amber
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .success:   return "Obuna faollashtirildi!"
        case .failed:    return "To'lov amalga oshmadi"
        case .cancelled: return "To'lov bekor qilindi"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .success:   return "Pro rejimi faol"
        case .failed:    return "Iltimos, qaytadan urinib ko'ring"
        case .cancelled: return "To'lov havolasi bekor qilindi"
        }
    }

    var haptic: HapticFeedback {
        switch self {
        case .success:   return .success
        case .failed:    return .error
        case .cancelled: return .warning
        }
    }
}

/// A single, identity-stamped toast instance. A fresh `id` each time guarantees
/// SwiftUI re-runs the enter transition even for two successive toasts of the
/// same kind.
struct PaymentToast: Identifiable, Equatable {
    let id = UUID()
    let kind: PaymentToastKind
    var plan: String?

    init(_ kind: PaymentToastKind, plan: String? = nil) {
        self.kind = kind
        self.plan = plan
    }
}

// MARK: - Banner view

private struct PaymentToastBanner: View {
    let toast: PaymentToast
    let onDismiss: () -> Void

    /// Vertical drag offset for swipe-up-to-dismiss.
    @State private var dragY: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.kind.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(toast.kind.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.kind.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(toast.kind.subtitle)
                    .font(.system(size: 12.5))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .salomGlassCard(18)
        .overlay(alignment: .leading) {
            // Accent rail hints at the outcome without shouting.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(toast.kind.tint)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .offset(y: min(dragY, 0))
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    if value.translation.height < 0 { dragY = value.translation.height }
                }
                .onEnded { value in
                    if value.translation.height < -28 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragY = 0 }
                    }
                }
        )
        .onTapGesture { onDismiss() }
    }
}

// MARK: - Host view

/// Observes `SubscriptionManager.paymentToast` and renders the banner top-aligned.
/// Lives inside the dedicated overlay window (see `ToastWindowController`) so it
/// floats above sheets / fullScreenCovers — never behind them.
private struct PaymentToastHost: View {
    @ObservedObject var manager = SubscriptionManager.shared

    /// Seconds the toast stays on screen before auto-dismissing.
    private let visibleDuration: TimeInterval = 3.2

    var body: some View {
        VStack {
            if let toast = manager.paymentToast {
                PaymentToastBanner(toast: toast) { dismiss() }
                    .id(toast.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        HapticManager.shared.fire(toast.kind.haptic)
                        try? await Task.sleep(nanoseconds: UInt64(visibleDuration * 1_000_000_000))
                        // Only auto-dismiss if this exact toast is still showing.
                        if manager.paymentToast?.id == toast.id { dismiss() }
                    }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: manager.paymentToast?.id)
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.22)) { manager.paymentToast = nil }
    }
}

// MARK: - Overlay window

/// A window that lets touches fall through everywhere except on its actual
/// content (the toast banner), so the app underneath stays fully interactive.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        // A hit on the hosting controller's own (transparent) root view means the
        // user tapped empty space → pass the touch through to the app below.
        return hit === rootViewController?.view ? nil : hit
    }
}

/// Installs a single top-most window that hosts the payment toast above every
/// sheet and cover in the app. Idempotent; safe to call on every toast.
@MainActor
final class ToastWindowController {
    static let shared = ToastWindowController()
    private var window: PassthroughWindow?

    private init() {}

    /// Ensures the overlay window exists and is attached to the active scene.
    func install() {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let host = UIHostingController(rootView: PaymentToastHost())
        host.view.backgroundColor = .clear

        let w = PassthroughWindow(windowScene: scene)
        w.windowLevel = .alert + 1          // above sheets, covers, and alerts
        w.backgroundColor = .clear
        w.rootViewController = host
        w.isHidden = false                  // visible, but never becomes key
        window = w
    }
}
