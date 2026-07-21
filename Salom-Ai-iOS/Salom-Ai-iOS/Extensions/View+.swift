//
//  View+.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V?) -> some View {
        if let result = block(self) {
            result
        } else {
            self
        }
    }
    
    /// Glass / frosted card. On iOS 26+ uses native Liquid Glass; iOS 17–25 falls
    /// back to ultraThinMaterial; below 17 a blurred fill. Same call site everywhere.
    func glassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 16) -> some View {
        self.apply { view in
            if #available(iOS 26.0, *) {
                view
                    .padding(padding)
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            } else if #available(iOS 17, *) {
                view
                    .padding(padding)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(SalomTheme.Colors.border)
                    )
            } else {
                view
                    .padding(padding)
                    .background(
                        SalomTheme.Colors.surfaceMuted.opacity(0.88)
                            .blur(radius: 16)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(SalomTheme.Colors.border)
                    )
            }
        }
    }
    
    func shimmerEffect(isLoading: @autoclosure () -> Bool) -> some View {
        redacted(reason: isLoading() ? .placeholder : []).shimmering(active: isLoading()).disabled(isLoading())
    }
}
