//
//  OnboardingViewModel.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"

    // Animations
    @State private var showContent: Bool = false
    @State private var backgroundRotation: Double = 0
    @State private var characterFloat: Bool = false
    
    var body: some View {
        ZStack {
            // 1. Dynamic Background
            BackgroundLayer()
            
            // 2. Main Content
            VStack(spacing: 0) {
                // Top Bar
                TopBar()
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                
                Spacer()
                
                // 3D Character Hero
                HeroSection()
                    .frame(maxHeight: .infinity)
                
                Spacer()
                
                // Bottom Card
                BottomCard()
                    .offset(y: showContent ? 0 : 100)
                    .opacity(showContent ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                backgroundRotation = 360
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                characterFloat = true
            }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func BackgroundLayer() -> some View {
        ZStack {
            Color(hex: "#020617").ignoresSafeArea()
            
            // Animated Aurora
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(SalomTheme.Colors.accentPrimary.opacity(0.3))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: -100, y: -200)
                    
                    Circle()
                        .fill(SalomTheme.Colors.accentSecondary.opacity(0.3))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: 100, y: 200)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .rotationEffect(.degrees(backgroundRotation))
            }
            
            // Noise Texture Overlay (Optional, simulated with opacity)
            Color.white.opacity(0.02)
                .blendMode(.overlay)
        }
    }
    
    @ViewBuilder
    private func TopBar() -> some View {
        HStack {
            // Logo
            HStack(spacing: 8) {
                Image("app-icon-transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                Text("Salom AI")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            // Language picker + Skip
            HStack(spacing: 10) {
                LanguageMenuButton()

                Button {
                    viewModel.markAsCompleted()
                } label: {
                    Text("O'tkazib yuborish")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Language Menu

    private var currentFlag: String {
        switch languageCode {
        case "ru":      return "🇷🇺"
        case "en":      return "🇬🇧"
        case "uz-Cyrl": return "🇺🇿"
        default:        return "🇺🇿"
        }
    }

    @ViewBuilder
    private func LanguageMenuButton() -> some View {
        Menu {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    languageCode = "uz"
                }
            } label: {
                Label {
                    Text("Oʻzbekcha")
                } icon: {
                    Text("🇺🇿")
                }
            }
            .disabled(languageCode == "uz")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    languageCode = "uz-Cyrl"
                }
            } label: {
                Label {
                    Text("Кириллча")
                } icon: {
                    Text("🇺🇿")
                }
            }
            .disabled(languageCode == "uz-Cyrl")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    languageCode = "ru"
                }
            } label: {
                Label {
                    Text("Русский")
                } icon: {
                    Text("🇷🇺")
                }
            }
            .disabled(languageCode == "ru")

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    languageCode = "en"
                }
            } label: {
                Label {
                    Text("English")
                } icon: {
                    Text("🇬🇧")
                }
            }
            .disabled(languageCode == "en")

        } label: {
            HStack(spacing: 4) {
                Text(currentFlag)
                    .font(.system(size: 16))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .contentShape(Capsule())
        }
        .menuStyle(.automatic)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: languageCode)
    }
    
    @ViewBuilder
    private func HeroSection() -> some View {
        ZStack {
            // Glow behind character
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SalomTheme.Colors.accentPrimary.opacity(0.5),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .blur(radius: 40)
                .scaleEffect(characterFloat ? 1.1 : 1.0)
            
            // Character Image
            Image("main-character-full-body")
                .resizable()
                .scaledToFit()
                .frame(height: UIScreen.main.bounds.height * 0.45)
                .offset(y: characterFloat ? -10 : 10)
                .shadow(color: SalomTheme.Colors.accentPrimary.opacity(0.3), radius: 30, x: 0, y: 20)
        }
    }
    
    @ViewBuilder
    private func BottomCard() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // Text Content
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.currentScene.tag)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(viewModel.currentScene.accent)
                    .tracking(1.5)
                    .textCase(.uppercase)
                
                Text(viewModel.currentScene.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id("title-\(viewModel.currentIndex)")
                
                Text(viewModel.currentScene.subtitle)
                    .font(.system(size: 17))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id("subtitle-\(viewModel.currentIndex)")
            }
            
            // Indicators & Button
            HStack(spacing: 20) {
                // Page Indicators
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.scenes.count, id: \.self) { index in
                        Capsule()
                            .fill(index == viewModel.currentIndex ? Color.white : Color.white.opacity(0.2))
                            .frame(width: index == viewModel.currentIndex ? 24 : 8, height: 8)
                            .animation(.spring(), value: viewModel.currentIndex)
                    }
                }
                
                Spacer()
                
                // Next Button
                Button {
                    HapticManager.shared.fire(.lightImpact)
                    if viewModel.isLastPage {
                        viewModel.markAsCompleted()
                    } else {
                        viewModel.goNext()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(SalomTheme.Gradients.accent)
                            .frame(width: 64, height: 64)
                            .shadow(color: SalomTheme.Colors.accentPrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(32)
        .background(
            Rectangle()
                .fill(Color(hex: "#0F172A").opacity(0.8))
                .background(.ultraThinMaterial)
                .mask(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .edgesIgnoringSafeArea(.bottom)
    }
}

final class OnboardingViewModel: ObservableObject {
    @Published var currentIndex: Int = 0
    
    struct Scene: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let tag: LocalizedStringKey
        let accent: Color
    }
    
    let scenes: [Scene] = [
        Scene(
            title: "O'zbek tilidagi birinchi AI hamroh",
            subtitle: "Sizning tilingizda, sizning madaniyatingizda. Salom AI bilan muloqot qiling va kundalik vazifalaringizni osonlashtiring.",
            tag: "Salom AI",
            accent: SalomTheme.Colors.accentPrimary
        ),
        Scene(
            title: "Ovozli suhbat, xuddi do'stingizdek",
            subtitle: "Yozish shart emas. Shunchaki gapiring va tabiiy ovozda javob oling. Haqiqiy suhbatdosh kabi.",
            tag: "Ovozli Rejim",
            accent: SalomTheme.Colors.accentSecondary
        ),
        Scene(
            title: "Cheksiz imkoniyatlar olami",
            subtitle: "O'qish, ish, ijod va shaxsiy rivojlanish. Salom AI sizga har qadamda yordam berishga tayyor.",
            tag: "Premium",
            accent: SalomTheme.Colors.accentTertiary
        )
    ]
    
    var currentScene: Scene {
        scenes[currentIndex]
    }
    
    var isLastPage: Bool {
        currentIndex == scenes.count - 1
    }
    
    func goNext() {
        if currentIndex < scenes.count - 1 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentIndex += 1
            }
        }
    }
    
    func markAsCompleted() {
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasCompletedOnboarding)
        withAnimation {
            SessionManager.shared.contentType = .login
        }
    }
}
