//
//  LoadingMessagesPlaceholder.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 24/11/25.
//

import SwiftUI

struct LoadingMessagesPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LoadingMessageRow(isUser: false, maxWidthMultiplier: 0.78)
                .shimmerEffect(isLoading: true)
            LoadingMessageRow(isUser: true,  maxWidthMultiplier: 0.74)
                .shimmerEffect(isLoading: true)
            LoadingMessageRow(isUser: false, maxWidthMultiplier: 0.65)
                .shimmerEffect(isLoading: true)
            LoadingMessageRow(isUser: true,  maxWidthMultiplier: 0.82)
                .shimmerEffect(isLoading: true)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}

struct LoadingMessageRow: View {
    let isUser: Bool
    let maxWidthMultiplier: CGFloat
    
    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 10)
                    .frame(maxWidth: UIScreen.main.bounds.width * (maxWidthMultiplier * 0.8))
                    .shimmering()
                
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 10)
                    .frame(maxWidth: UIScreen.main.bounds.width * (maxWidthMultiplier * 0.5))
                    .shimmering()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        isUser
                        ? LinearGradient(
                            colors: [
                                SalomTheme.Colors.accentPrimary.opacity(0.8),
                                SalomTheme.Colors.accentSecondary.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.07),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(isUser ? 0.14 : 0.06))
                    )
            )
            .frame(
                maxWidth: UIScreen.main.bounds.width * maxWidthMultiplier,
                alignment: isUser ? .trailing : .leading
            )
            
            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 4)
        .transition(.opacity)
    }
}
