//
//  SplashView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

struct SplashView: View {
    @Binding var isActive: Bool
    
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var glow: Double = 0.0
    
    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()
            
            RadialGradient(
                colors: [
                    SalomTheme.Colors.accentSecondary.opacity(0.35),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .blur(radius: 40)
            .opacity(0.9)
            .offset(y: 100)
            
            VStack(spacing: 16) {
                Image(.appIconTransparent)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Text("Salom AI")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
                
                Text("O'zbek ai yordamchisi")
                    .font(.callout)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
            }
        }
        .onAppear {
            animateIn()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation {
                    isActive = false
                }
            }
        }
    }
    
    func animateIn() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
            logoScale = 1.05
            logoOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            glow = 1.0
        }
    }
}

#Preview {
    SplashView(isActive: .constant(true))
}
