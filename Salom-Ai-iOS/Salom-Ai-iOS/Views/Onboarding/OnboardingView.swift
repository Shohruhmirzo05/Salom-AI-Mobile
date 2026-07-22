//
//  OnboardingView.swift
//  Salom-Ai-iOS
//
//  Comprehensive onboarding — 7 scenes covering core app capabilities.
//  Custom SwiftUI illustrations (no Lottie dependency).
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"

    // Master animations
    @State private var showContent: Bool = false
    @State private var backgroundRotation: Double = 0
    @State private var heroPulse: Bool = false
    // Persona questionnaire shown after the capability scenes (before finishing).
    @State private var showPersona: Bool = false

    var body: some View {
        ZStack {
            BackgroundLayer()

            VStack(spacing: 0) {
                TopBar()
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)

                Spacer()

                // Per-scene hero — switches with crossfade
                HeroContainer(scene: viewModel.currentScene, pulse: heroPulse)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .id("hero-\(viewModel.currentIndex)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))

                Spacer()

                BottomCard()
                    .offset(y: showContent ? 0 : 100)
                    .opacity(showContent ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -50 { goNext() }
                    else if value.translation.width > 50 { goBack() }
                }
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { showContent = true }
            withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                backgroundRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                heroPulse = true
            }
        }
        .fullScreenCover(isPresented: $showPersona) {
            PersonaFlowView { role, goals in
                PersonaStore.saveLocal(role: role, goals: goals)
                Analytics.shared.trackOnce("onboarding_completed", ["role": role ?? "skip", "goals": goals.count])
                HapticManager.shared.fire(.success)
                showPersona = false
                viewModel.markAsCompleted()
            }
        }
    }

    private func goNext() {
        HapticManager.shared.fire(.lightImpact)
        if viewModel.isLastPage {
            // Last capability scene → ask the persona questions before finishing.
            Analytics.shared.trackOnce("onboarding_persona_shown")
            showPersona = true
        } else {
            viewModel.goNext()
        }
    }

    private func goBack() {
        guard viewModel.currentIndex > 0 else { return }
        HapticManager.shared.fire(.selection)
        viewModel.goPrev()
    }

    // MARK: - Background

    @ViewBuilder
    private func BackgroundLayer() -> some View {
        ZStack {
            SalomTheme.Colors.bgMain.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(viewModel.currentScene.accent.opacity(0.32))
                        .frame(width: 320, height: 320)
                        .blur(radius: 90)
                        .offset(x: -100, y: -200)

                    Circle()
                        .fill(viewModel.currentScene.accent2.opacity(0.28))
                        .frame(width: 320, height: 320)
                        .blur(radius: 90)
                        .offset(x: 100, y: 200)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .rotationEffect(.degrees(backgroundRotation))
                .animation(.easeInOut(duration: 0.6), value: viewModel.currentIndex)
            }

            SalomTheme.Colors.textPrimary.opacity(0.02).blendMode(.overlay)
        }
    }

    // MARK: - Top bar

    @ViewBuilder
    private func TopBar() -> some View {
        HStack {
            HStack(spacing: 8) {
                Image("app-icon-transparent")
                    .resizable().scaledToFit()
                    .frame(width: 28, height: 28)
                Text("Salom AI")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
            }
            Spacer()
            HStack(spacing: 10) {
                LanguageMenuButton()
                Button {
                    HapticManager.shared.fire(.selection)
                    Analytics.shared.trackOnce("onboarding_persona_shown", ["source": "capability_skip"])
                    showPersona = true
                } label: {
                    Text("O'tkazib yuborish")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
            }
        }
    }

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
            Button { setLang("uz") } label: { Label { Text("Oʻzbekcha") } icon: { Text("🇺🇿") } }
                .disabled(languageCode == "uz")
            Button { setLang("uz-Cyrl") } label: { Label { Text("Кириллча") } icon: { Text("🇺🇿") } }
                .disabled(languageCode == "uz-Cyrl")
            Button { setLang("ru") } label: { Label { Text("Русский") } icon: { Text("🇷🇺") } }
                .disabled(languageCode == "ru")
            Button { setLang("en") } label: { Label { Text("English") } icon: { Text("🇬🇧") } }
                .disabled(languageCode == "en")
        } label: {
            HStack(spacing: 4) {
                Text(currentFlag).font(.system(size: 16))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(SalomTheme.Colors.surfaceMuted)
                    .overlay(Capsule().stroke(SalomTheme.Colors.border, lineWidth: 0.5))
            )
            .contentShape(Capsule())
        }
    }

    private func setLang(_ code: String) {
        HapticManager.shared.fire(.selection)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            languageCode = code
        }
    }

    // MARK: - Bottom card

    @ViewBuilder
    private func BottomCard() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.currentScene.tag)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(viewModel.currentScene.accent)
                    .tracking(1.5)
                    .textCase(.uppercase)
                Text(viewModel.currentScene.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id("title-\(viewModel.currentIndex)")
                Text(viewModel.currentScene.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .id("subtitle-\(viewModel.currentIndex)")
            }

            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.scenes.count, id: \.self) { index in
                        Capsule()
                            .fill(index == viewModel.currentIndex ? SalomTheme.Colors.textPrimary : SalomTheme.Colors.textTertiary.opacity(0.35))
                            .frame(width: index == viewModel.currentIndex ? 24 : 8, height: 8)
                            .animation(.spring(), value: viewModel.currentIndex)
                    }
                }
                Spacer()
                Button(action: goNext) {
                    ZStack {
                        Circle()
                            .fill(SalomTheme.Gradients.accent)
                            .frame(width: 64, height: 64)
                            .shadow(color: SalomTheme.Colors.accentPrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                        Image(systemName: viewModel.isLastPage ? "checkmark" : "arrow.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(28)
        .background(bottomCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .edgesIgnoringSafeArea(.bottom)
    }

    @ViewBuilder
    private var bottomCardSurface: some View {
        if #available(iOS 26.0, *) {
            SalomTheme.Colors.surface.opacity(0.72)
                .glassEffect(.regular, in: .rect(cornerRadius: 40, style: .continuous))
                .shadow(color: SalomTheme.Colors.textPrimary.opacity(0.12), radius: 20, x: 0, y: -10)
        } else {
            Rectangle()
                .fill(SalomTheme.Colors.surface.opacity(0.86))
                .background(.ultraThinMaterial)
                .mask(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .shadow(color: SalomTheme.Colors.textPrimary.opacity(0.12), radius: 20, x: 0, y: -10)
        }
    }
}

// MARK: - Hero container (switches per-scene illustration)

private struct HeroContainer: View {
    let scene: OnboardingViewModel.Scene
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [scene.accent.opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: 220
                    )
                )
                .blur(radius: 50)
                .scaleEffect(pulse ? 1.1 : 1.0)

            switch scene.kind {
            case .welcome:    WelcomeHero(pulse: pulse)
            case .chat:       ChatHero(pulse: pulse, accent: scene.accent)
            case .voice:      VoiceHero(pulse: pulse, accent: scene.accent)
            case .image:      ImageHero(pulse: pulse, accent: scene.accent)
            case .files:      FilesHero(pulse: pulse, accent: scene.accent)
            case .planning:   PlanningHero(pulse: pulse, accent: scene.accent)
            case .ready:      ReadyHero(pulse: pulse, accent: scene.accent)
            }
        }
    }
}

// MARK: - Scene heroes

private struct WelcomeHero: View {
    let pulse: Bool
    var body: some View {
        Image("main-character-full-body")
            .resizable().scaledToFit()
            .frame(height: UIScreen.main.bounds.height * 0.42)
            .offset(y: pulse ? -10 : 10)
            .shadow(color: SalomTheme.Colors.accentPrimary.opacity(0.35), radius: 30, x: 0, y: 20)
    }
}

private struct ChatHero: View {
    let pulse: Bool
    let accent: Color
    @State private var typingDot = 0
    var body: some View {
        VStack(spacing: 14) {
            ChatBubble(text: "Direktorga rasmiy ariza yozib ber", isUser: true, accent: accent)
                .offset(y: pulse ? -2 : 2)
            ChatBubble(text: "Albatta! Mana professional uslubdagi ariza...", isUser: false, accent: accent)
                .offset(y: pulse ? 2 : -2)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(SalomTheme.Colors.textPrimary.opacity(typingDot == i ? 0.9 : 0.25))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Capsule().fill(SalomTheme.Colors.surfaceMuted))
        }
        .frame(maxWidth: 320)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                typingDot = (typingDot + 1) % 3
            }
        }
    }
}

private struct ChatBubble: View {
    let text: String
    let isUser: Bool
    let accent: Color
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isUser ? SalomTheme.Colors.onAccent : SalomTheme.Colors.textPrimary)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isUser ? accent.opacity(0.9) : SalomTheme.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(SalomTheme.Colors.border, lineWidth: isUser ? 0 : 1)
                        )
                )
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

private struct VoiceHero: View {
    let pulse: Bool
    let accent: Color
    @State private var bars: [CGFloat] = Array(repeating: 0.4, count: 21)
    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.4), lineWidth: 2)
                    .frame(width: pulse ? 200 : 170, height: pulse ? 200 : 170)
                Circle()
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 130, height: 130)
                    .shadow(color: accent.opacity(0.5), radius: 30)
                Image(systemName: "mic.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
            HStack(spacing: 4) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(accent)
                        .frame(width: 4, height: bars[i] * 50)
                }
            }
            .frame(height: 50)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
                bars = bars.map { _ in CGFloat.random(in: 0.2...1.0) }
            }
        }
    }
}

private struct ImageHero: View {
    let pulse: Bool
    let accent: Color
    @State private var sparkRotate: Double = 0
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [accent.opacity(0.6), accent.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 160)
                    .rotationEffect(.degrees(Double(i - 2) * 8 + (pulse ? 2 : -2)))
                    .offset(x: CGFloat(i - 2) * 14, y: CGFloat(abs(i - 2)) * 6)
                    .shadow(color: accent.opacity(0.4), radius: 15, x: 0, y: 8)
                    .opacity(0.3 + 0.15 * Double(5 - abs(i - 2)))
            }
            Image(systemName: "sparkles")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.white, accent], startPoint: .top, endPoint: .bottom))
                .rotationEffect(.degrees(sparkRotate))
                .shadow(color: .white.opacity(0.5), radius: 12)
        }
        .onAppear {
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { sparkRotate = 360 }
        }
    }
}

private struct FilesHero: View {
    let pulse: Bool
    let accent: Color
    @State private var scanY: CGFloat = -80
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(SalomTheme.Colors.surface)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(SalomTheme.Colors.border, lineWidth: 1))
                .overlay(
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<6, id: \.self) { i in
                            Capsule()
                                .fill(SalomTheme.Colors.textPrimary.opacity(i == 0 ? 0.55 : 0.18))
                                .frame(width: i == 0 ? 130 : CGFloat.random(in: 80...170), height: 8)
                        }
                    }
                    .padding(20)
                )
                .frame(width: 220, height: 280)
                .overlay(
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, accent.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 3)
                        .blur(radius: 2)
                        .offset(y: scanY)
                        .mask(RoundedRectangle(cornerRadius: 18, style: .continuous).frame(width: 220, height: 280))
                )
                .shadow(color: accent.opacity(0.3), radius: 30, x: 0, y: 16)
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(SalomTheme.Colors.textPrimary)
                .offset(y: 170)
                .opacity(pulse ? 1.0 : 0.5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                scanY = 80
            }
        }
    }
}

private struct PlanningHero: View {
    let pulse: Bool
    let accent: Color
    var body: some View {
        VStack(spacing: 14) {
            ChecklistRow(text: "2x + 5 = 13 → x = 4", icon: "function", accent: accent, done: true)
            ChecklistRow(text: "Bugun ish rejasi", icon: "calendar", accent: accent, done: true)
            ChecklistRow(text: "Sayohat marshruti", icon: "map", accent: accent, done: pulse)
            ChecklistRow(text: "Email javobi", icon: "envelope", accent: accent, done: false)
        }
        .frame(maxWidth: 320)
    }
}

private struct ChecklistRow: View {
    let text: String
    let icon: String
    let accent: Color
    let done: Bool
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? accent : SalomTheme.Colors.surfaceMuted)
                    .frame(width: 36, height: 36)
                Image(systemName: done ? "checkmark" : icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(done ? SalomTheme.Colors.onAccent : SalomTheme.Colors.textSecondary)
            }
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textPrimary)
                .strikethrough(done, color: SalomTheme.Colors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18).fill(SalomTheme.Colors.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(SalomTheme.Colors.border, lineWidth: 1))
    }
}

private struct ReadyHero: View {
    let pulse: Bool
    let accent: Color
    @State private var ringScale: CGFloat = 0.7
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(accent.opacity(0.4 - Double(i) * 0.12), lineWidth: 2)
                    .frame(width: 140 + CGFloat(i) * 60, height: 140 + CGFloat(i) * 60)
                    .scaleEffect(ringScale)
            }
            Circle()
                .fill(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 130, height: 130)
                .shadow(color: accent.opacity(0.55), radius: 30)
            Image(systemName: "checkmark")
                .font(.system(size: 60, weight: .black))
                .foregroundColor(.white)
                .scaleEffect(pulse ? 1.08 : 0.96)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: true)) { ringScale = 1.05 }
        }
    }
}

// MARK: - ViewModel

final class OnboardingViewModel: ObservableObject {
    @Published var currentIndex: Int = 0

    enum SceneKind { case welcome, chat, voice, image, files, planning, ready }

    struct Scene: Identifiable {
        let id = UUID()
        let kind: SceneKind
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let tag: LocalizedStringKey
        let accent: Color
        let accent2: Color
    }

    let scenes: [Scene] = [
        Scene(
            kind: .welcome,
            title: "O'zbek tilidagi birinchi AI hamroh",
            subtitle: "Sizning tilingizda, sizning madaniyatingizda. Salom AI bilan kundalik vazifalarni osonlashtiring.",
            tag: "Xush kelibsiz",
            accent: SalomTheme.Colors.accentPrimary,
            accent2: SalomTheme.Colors.accentSecondary
        ),
        Scene(
            kind: .chat,
            title: "Aqlli suhbatdosh",
            subtitle: "Yozing, savol bering, fikrlashing. AI sizning matnlaringizga aniq va tabiiy javob beradi — o'zbek, rus va ingliz tillarida.",
            tag: "Chat",
            accent: SalomTheme.Colors.accentSecondary,
            accent2: SalomTheme.Colors.accentPrimary
        ),
        Scene(
            kind: .voice,
            title: "Ovozli suhbat, real vaqtda",
            subtitle: "Mikrofonni bosing va gapiring. Salom AI sizni eshitadi, tushunadi va o'z ovozi bilan javob beradi.",
            tag: "Ovozli rejim",
            accent: SalomTheme.Colors.accentPrimary,
            accent2: SalomTheme.Colors.accentTertiary
        ),
        Scene(
            kind: .image,
            title: "Tasavvuringizni chizamiz",
            subtitle: "Bir necha so'z bilan istalgan rasm — afisha, dizayn, illyustratsiya — yarating. Bir necha soniyada tayyor.",
            tag: "Rasm yaratish",
            accent: SalomTheme.Colors.accentTertiary,
            accent2: SalomTheme.Colors.accentPrimary
        ),
        Scene(
            kind: .files,
            title: "Hujjat va rasmlarni tahlil qilish",
            subtitle: "PDF, rasm, kvitansiya, kontrakt — fayl yuboring, AI o'qiydi, tarjima qiladi va xulosa beradi.",
            tag: "Fayl tahlili",
            accent: SalomTheme.Colors.accentSecondary,
            accent2: SalomTheme.Colors.accentTertiary
        ),
        Scene(
            kind: .planning,
            title: "Reja, hisob va muammolar yechimi",
            subtitle: "Matematika, dasturlash, kunlik reja, sayohat marshruti — eng kerakli vazifalarni yo'lda hal qiling.",
            tag: "Reja va hisob",
            accent: SalomTheme.Colors.accentPrimary,
            accent2: SalomTheme.Colors.accentSecondary
        ),
        Scene(
            kind: .ready,
            title: "Boshlashga tayyormiz",
            subtitle: "Hamma narsa tayyor. Salom AI bilan birinchi suhbatingizni boshlang — yangi imkoniyatlar olamiga xush kelibsiz.",
            tag: "Tayyor",
            accent: SalomTheme.Colors.accentTertiary,
            accent2: SalomTheme.Colors.accentPrimary
        )
    ]

    var currentScene: Scene { scenes[currentIndex] }
    var isLastPage: Bool { currentIndex == scenes.count - 1 }

    func goNext() {
        guard currentIndex < scenes.count - 1 else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            currentIndex += 1
        }
    }

    func goPrev() {
        guard currentIndex > 0 else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            currentIndex -= 1
        }
    }

    func markAsCompleted() {
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasCompletedOnboarding)
        withAnimation {
            SessionManager.shared.contentType = .login
        }
    }
}
