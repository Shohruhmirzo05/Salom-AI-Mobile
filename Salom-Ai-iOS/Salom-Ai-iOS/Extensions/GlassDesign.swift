//
//  GlassDesign.swift
//  Salom-Ai-iOS
//
//  Liquid Glass design system. On iOS 26+ uses Apple's native Liquid Glass
//  (.glassEffect / .buttonStyle(.glass)); on iOS < 26 it falls back to the app's
//  EXISTING material/card styling so nothing changes for older devices (backup).
//
//  Usage:
//    SomeCard().salomGlassCard()
//    Image(systemName: "chevron.left").salomGlassCircle()   // back/menu buttons
//    Button("Go") { }.salomGlassButton(prominent: true)
//

import SwiftUI

extension View {
    /// Rounded glass surface for cards/panels.
    @ViewBuilder
    func salomGlassCard(_ cornerRadius: CGFloat = 20, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: .rect(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
    }

    /// Circular glass surface for icon buttons (back, menu, close…).
    @ViewBuilder
    func salomGlassCircle(_ size: CGFloat = 40) -> some View {
        if #available(iOS 26.0, *) {
            self.frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            self.frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    /// Capsule glass surface for pill buttons/chips.
    @ViewBuilder
    func salomGlassPill() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

/// A native-feeling circular icon button (back / menu / close). Liquid Glass on
/// iOS 26+, material fallback below. Adds haptics + press scale for an iOS feel.
struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 40
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            HapticManager.shared.fire(.selection)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .salomGlassCircle(size)
                .scaleEffect(pressed ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.12)) { pressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressed = false } }
        )
    }
}

/// Primary/secondary button surface. `prominent` = solid accent capsule;
/// otherwise a glass pill (Liquid Glass on iOS 26+, material below). We apply
/// the glass via background rather than `.buttonStyle(.glass)` for SDK safety.
struct GlassButtonModifier: ViewModifier {
    var prominent: Bool
    func body(content: Content) -> some View {
        if prominent {
            content
                .foregroundColor(.white)
                .background(
                    LinearGradient(colors: [Color(hex: "#1ED6FF"), Color(hex: "#7C3AED")],
                                   startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
        } else {
            content.salomGlassPill()
        }
    }
}

extension View {
    func salomGlassButton(prominent: Bool = false) -> some View {
        modifier(GlassButtonModifier(prominent: prominent))
    }
}
