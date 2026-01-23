//
//  Untitled.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

enum SalomTheme {
    enum Colors {
        static let bgMain          = Color(hex: "#050617")
        static let bgSecondary     = Color(hex: "#080A1F")
        static let accentPrimary   = Color(hex: "#7C3AED") // deep purple
        static let accentSecondary = Color(hex: "#1ED6FF") // cyan-blue glow
        static let accentTertiary  = Color(hex: "#4B87FF")
        static let textPrimary     = Color.white
        static let textSecondary   = Color.white.opacity(0.72)
        static let danger          = Color(hex: "#F97373")
    }

    enum Gradients {
        static let background = LinearGradient(
            colors: [
                Color(hex: "#06071C"),
                Color(hex: "#0B0E26"),
                Color(hex: "#0A0B22")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accent = LinearGradient(
            colors: [
                Color(hex: "#1ED6FF"),
                Color(hex: "#A855F7")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
