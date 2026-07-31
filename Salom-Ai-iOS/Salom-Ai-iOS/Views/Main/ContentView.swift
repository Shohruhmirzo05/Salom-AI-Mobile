//
//  ContentView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding)
    private var hasCompletedOnboarding: Bool = false
    
    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"
    
    @StateObject private var session = SessionManager.shared
    @ObservedObject private var trackingAuthorization = TrackingAuthorizationManager.shared
    @State private var showSplash: Bool = true
    // Observe the payment-abandon survey flag (set after a non-paid checkout return).
    @ObservedObject private var subs = SubscriptionManager.shared
    @ObservedObject private var deepLinks = AppDeepLinkRouter.shared
    @State private var showPersonaOnboarding = false
    @State private var promptedPersonaThisSession = false
#if DEBUG
    @State private var qaPaywallContext: PaywallContextID?
    @State private var qaChat = false
    @State private var qaSurface: String?
#endif

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()
            if debugQAPreviewEnabled {
                debugQARoot
            } else if showSplash {
                SplashView(isActive: $showSplash)
                    .transition(.opacity)
            } else if trackingAuthorization.needsOnboardingStep {
                TrackingPermissionView(
                    isRequesting: trackingAuthorization.isRequesting,
                    onContinue: trackingAuthorization.requestAuthorization
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if session.contentType == .onboarding || !hasCompletedOnboarding {
                OnboardingView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if session.contentType == .login {
                AuthView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ChatContainerView()
                    .transition(.opacity)
                    .featureTipToast(isPro: subs.isPro)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: trackingAuthorization.needsOnboardingStep)
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: session.contentType)
        .onAppear {
            trackingAuthorization.startAdsIfAuthorizationResolved()
            session.bootstrap(hasCompletedOnboarding: hasCompletedOnboarding)
            Analytics.shared.track("feature_opened", ["feature": "ios_app"])
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            qaChat = arguments.contains("-SALOM_QA_CHAT")
            if let marker = arguments.firstIndex(of: "-SALOM_QA_SURFACE"),
               arguments.indices.contains(marker + 1) {
                qaSurface = arguments[marker + 1]
            }
            if let marker = arguments.firstIndex(of: "-SALOM_QA_PAYWALL"),
               arguments.indices.contains(marker + 1) {
                qaPaywallContext = PaywallContextID(rawValue: arguments[marker + 1])
            }
#endif
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallSheet(context: .onboardingPersona, source: "ios_first_value")
        }
        .fullScreenCover(isPresented: $showPersonaOnboarding) {
            PersonaFlowView { role, goals in
                if let role {
                    PersonaStore.saveLocal(role: role, goals: goals)
                    PersonaStore.syncIfPending()
                    Analytics.shared.track("onboarding_completed", ["platform": "ios", "role": role, "goals": goals.count])
                } else {
                    Analytics.shared.track("onboarding_skipped", ["platform": "ios", "surface": "persona_resume"])
                }
                showPersonaOnboarding = false
            }
        }
        .fullScreenCover(item: paywallDeepLinkBinding) { request in
            PaywallSheet(context: request.context, source: request.source)
        }
#if DEBUG
        .fullScreenCover(item: $qaPaywallContext) { context in
            PaywallSheet(context: context, source: "ios_debug_visual_qa")
        }
#endif
        .fullScreenCover(item: $winBackOffer) { offer in
            WinBackOfferSheet(offer: offer)
        }
        .sheet(isPresented: paymentSurveyBinding) {
            // "Why didn't you pay?" after a returned-but-not-paid checkout.
            WhyNotPaySurvey(
                onPick: { reason in
                    finishPaymentSurvey(reason: reason)
                },
                onSkip: { finishPaymentSurvey(reason: nil) }
            )
            .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $showValueShowcase) {
            // "What can you do with Salom AI?" — first-run value showcase.
            ValueShowcaseSheet(onSeePro: { showPaywall = true })
                .presentationDetents([.large])
        }
        .onReceive(NotificationCenter.default.publisher(for: .showValueShowcase)) { _ in
            showValueShowcase = true
        }
        .onChange(of: showSplash) { _, isSplashActive in
            if !isSplashActive {
                print("DEBUG: Splash finished. Checking paywall.")
                checkAndShowPaywall()
            }
        }
        .onChange(of: session.contentType) { _, newValue in
            if newValue == .main && !showSplash {
                 checkAndShowPaywall()
                 // Push onboarding persona answers now that we're logged in.
                 PersonaStore.syncIfPending()
                 presentPersonaIfNeeded()
            } else if newValue != .main {
                // A payment prompt must never leak across logout/auth/onboarding.
                subs.resetPaymentRecovery()
            }
        }
    }

    private var debugQAPreviewEnabled: Bool {
#if DEBUG
        qaChat || qaSurface != nil
#else
        false
#endif
    }

    @ViewBuilder
    private var debugQARoot: some View {
#if DEBUG
        if let rawSurface = qaSurface {
            if rawSurface == "ish-document" {
                WorkDetailView(previewDocument: .appStorePreview, docLang: "uz")
            } else if rawSurface == "realtime-preview" {
                RealtimeVoiceView(previewState: .listening)
            } else if rawSurface.hasPrefix("miniapp:"),
               let app = RemoteMiniApp.catalog.first(where: {
                   $0.id == String(rawSurface.dropFirst("miniapp:".count))
               }) {
                RemoteMiniAppView(app: app)
            } else {
                ChatContainerView(initialSection: MainSection(rawValue: rawSurface) ?? .apps)
            }
        } else {
            ChatContainerView()
        }
#else
        EmptyView()
#endif
    }

    private var paymentSurveyBinding: Binding<Bool> {
        Binding(
            get: {
                session.contentType == .main
                    && TokenStore.shared.accessToken != nil
                    && subs.showPaymentSurvey
            },
            set: { subs.showPaymentSurvey = $0 }
        )
    }

    private var paywallDeepLinkBinding: Binding<PaywallDeepLinkRequest?> {
        Binding(
            get: {
                session.contentType == .main && TokenStore.shared.accessToken != nil
                    ? deepLinks.paywallRequest
                    : nil
            },
            set: { deepLinks.paywallRequest = $0 }
        )
    }
    
    @State private var showPaywall = false
    @State private var hasShownPaywall = false
    @State private var winBackOffer: RecoveryOffer?
    // First-run value showcase ("what can you do") — shown once, before any paywall.
    @AppStorage("value_shown_v1") private var valueShown: Bool = false
    @State private var showValueShowcase = false

    private func checkAndShowPaywall() {
        guard !hasShownPaywall else { return }
        guard !showSplash else { return }
        guard session.contentType == .main else { return }

        Task {
            // Always await a fresh subscription check before deciding.
            // During the splash path this is a no-op (data already loaded).
            // After a fresh login the subscription check hasn't completed yet,
            // so we must wait here to avoid a false-negative isPro = false.
            await SubscriptionManager.shared.checkSubscriptionStatus()

            let isPro = SubscriptionManager.shared.isPro

            await MainActor.run {
                hasShownPaywall = true  // mark regardless, so we never re-check
            }

            guard !isPro else { return }

            // First-ever open → show the value showcase (once) INSTEAD of the
            // paywall, so a brand-new user learns the breadth before being sold.
            // Its "See Pro" button opens the paywall on demand.
            if !valueShown {
                await MainActor.run {
                    valueShown = true
                    showValueShowcase = true
                }
                return
            }

            // Returning free users go straight to their task. Paywalls are shown
            // at a feature limit/export/explicit upgrade action, never on launch.
        }
    }

    private func presentPersonaIfNeeded() {
        guard !PersonaStore.isCompleted, !promptedPersonaThisSession else { return }
        promptedPersonaThisSession = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard session.contentType == .main, !showPaywall, deepLinks.paywallRequest == nil else { return }
            showPersonaOnboarding = true
        }
    }

    private func finishPaymentSurvey(reason: String?) {
        subs.showPaymentSurvey = false
        Task {
            if let reason {
                await SubscriptionManager.shared.submitCancelSurvey(reason: reason)
            }
            if let offer = await SubscriptionManager.shared.fetchAbandonedCheckoutOffer() {
                await MainActor.run { winBackOffer = offer }
            }
        }
    }

}

// MARK: - Privacy onboarding

private struct TrackingPermissionView: View {
    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"

    let isRequesting: Bool
    let onContinue: () -> Void

    private var copy: TrackingPermissionCopy {
        TrackingPermissionCopy(languageCode: languageCode)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    topBar

                    Spacer(minLength: 30)

                    privacyIllustration
                        .padding(.bottom, 34)

                    VStack(spacing: 14) {
                        Text(copy.eyebrow)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(SalomTheme.Colors.accentPrimary)

                        Text(copy.title)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(copy.subtitle)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.center)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 560)

                    privacyBenefits
                        .padding(.top, 28)

                    Spacer(minLength: 32)

                    continueButton

                    Text(copy.footnote)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                        .foregroundColor(SalomTheme.Colors.textTertiary)
                        .lineSpacing(2)
                        .padding(.top, 14)
                        .frame(maxWidth: 520)
                }
                .padding(.horizontal, min(max(proxy.size.width * 0.07, 22), 72))
                .padding(.top, max(proxy.safeAreaInsets.top, 12))
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 22))
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
            .background(background)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 9) {
                Image("app-icon-transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)

                Text("Salom AI")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(SalomTheme.Colors.textPrimary)
            }

            Spacer()

            Menu {
                languageButton("Oʻzbekcha", flag: "🇺🇿", code: "uz")
                languageButton("Кириллча", flag: "🇺🇿", code: "uz-Cyrl")
                languageButton("Русский", flag: "🇷🇺", code: "ru")
                languageButton("English", flag: "🇬🇧", code: "en")
            } label: {
                HStack(spacing: 5) {
                    Text(currentFlag)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 15))
                .foregroundColor(SalomTheme.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(SalomTheme.Colors.surface)
                        .overlay(Capsule().stroke(SalomTheme.Colors.border, lineWidth: 1))
                )
            }
        }
    }

    private var privacyIllustration: some View {
        ZStack {
            Circle()
                .fill(SalomTheme.Colors.accentPrimary.opacity(0.11))
                .frame(width: 230, height: 230)

            Circle()
                .stroke(SalomTheme.Colors.accentPrimary.opacity(0.17), lineWidth: 1)
                .frame(width: 188, height: 188)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            SalomTheme.Colors.accentPrimary,
                            SalomTheme.Colors.accentSecondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 132, height: 150)
                .shadow(
                    color: SalomTheme.Colors.accentPrimary.opacity(0.3),
                    radius: 26,
                    x: 0,
                    y: 16
                )
                .overlay {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundColor(.white)
                }

            privacyBadge(systemName: "slider.horizontal.3", x: -92, y: 55)
            privacyBadge(systemName: "lock.fill", x: 94, y: -45)
            privacyBadge(systemName: "checkmark.shield.fill", x: -82, y: -75)
        }
        .accessibilityHidden(true)
    }

    private func privacyBadge(systemName: String, x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(SalomTheme.Colors.accentPrimary)
            .frame(width: 48, height: 48)
            .background(
                Circle()
                    .fill(SalomTheme.Colors.surface)
                    .shadow(color: Color.black.opacity(0.09), radius: 12, x: 0, y: 6)
            )
            .overlay(Circle().stroke(SalomTheme.Colors.border, lineWidth: 1))
            .offset(x: x, y: y)
    }

    private var privacyBenefits: some View {
        HStack(spacing: 12) {
            benefit(
                icon: "person.crop.circle.badge.checkmark",
                title: copy.relevantTitle,
                subtitle: copy.relevantSubtitle
            )
            benefit(
                icon: "hand.tap.fill",
                title: copy.controlTitle,
                subtitle: copy.controlSubtitle
            )
        }
        .frame(maxWidth: 620)
    }

    private func benefit(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.accentPrimary)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(SalomTheme.Colors.accentPrimary.opacity(0.1))
                )

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(SalomTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(SalomTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SalomTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SalomTheme.Colors.border, lineWidth: 1)
                )
        )
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            HStack(spacing: 10) {
                if isRequesting {
                    ProgressView()
                        .tint(.white)
                }

                Text(copy.continueTitle)
                    .font(.system(size: 17, weight: .bold))

                if !isRequesting {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: 560)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SalomTheme.Gradients.accent)
                    .shadow(
                        color: SalomTheme.Colors.accentPrimary.opacity(0.3),
                        radius: 18,
                        x: 0,
                        y: 9
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
        .accessibilityIdentifier("tracking_consent_continue")
    }

    private var background: some View {
        ZStack {
            SalomTheme.Colors.bgMain

            Circle()
                .fill(SalomTheme.Colors.accentPrimary.opacity(0.13))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: -220, y: -300)

            Circle()
                .fill(SalomTheme.Colors.accentSecondary.opacity(0.11))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: 230, y: 330)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func languageButton(_ title: String, flag: String, code: String) -> some View {
        Button {
            HapticManager.shared.fire(.selection)
            languageCode = code
        } label: {
            Label {
                Text(title)
            } icon: {
                Text(flag)
            }
        }
        .disabled(languageCode == code)
    }

    private var currentFlag: String {
        switch languageCode {
        case "uz-Cyrl": "🇺🇿"
        case "ru": "🇷🇺"
        case "en": "🇬🇧"
        default: "🇺🇿"
        }
    }
}

private struct TrackingPermissionCopy {
    let eyebrow: String
    let title: String
    let subtitle: String
    let relevantTitle: String
    let relevantSubtitle: String
    let controlTitle: String
    let controlSubtitle: String
    let continueTitle: String
    let footnote: String

    init(languageCode: String) {
        switch languageCode {
        case "uz-Cyrl":
            eyebrow = "МАХФИЙЛИК"
            title = "Танлов доим сизда"
            subtitle = "Salom AI бепул имкониятларни реклама орқали қўллаб-қувватлайди. Рухсат берсангиз, сизга мосроқ рекламалар кўрсатилади."
            relevantTitle = "Мосроқ реклама"
            relevantSubtitle = "Қизиқишларингизга яқин таклифлар"
            controlTitle = "Сиз бошқарасиз"
            controlSubtitle = "Рад этсангиз ҳам илова тўлиқ ишлайди"
            continueTitle = "Давом этиш"
            footnote = "Кейинги Apple ойнасида рухсат бериш ёки рад этишни ўзингиз танлайсиз."
        case "ru":
            eyebrow = "КОНФИДЕНЦИАЛЬНОСТЬ"
            title = "Вы всегда решаете сами"
            subtitle = "Реклама помогает сохранять бесплатные возможности Salom AI. С разрешением объявления будут более полезными для вас."
            relevantTitle = "Полезнее для вас"
            relevantSubtitle = "Предложения ближе к вашим интересам"
            controlTitle = "Вы всё контролируете"
            controlSubtitle = "При отказе приложение продолжит работать"
            continueTitle = "Продолжить"
            footnote = "В следующем окне Apple вы сами выберете, разрешить отслеживание или нет."
        case "en":
            eyebrow = "PRIVACY"
            title = "You’re always in control"
            subtitle = "Ads help keep Salom AI’s free features available. With permission, the ads you see can be more relevant."
            relevantTitle = "More relevant"
            relevantSubtitle = "Offers closer to your interests"
            controlTitle = "Your choice"
            controlSubtitle = "The app still works if you decline"
            continueTitle = "Continue"
            footnote = "In the next Apple dialog, you can choose whether to allow tracking."
        default:
            eyebrow = "MAXFIYLIK"
            title = "Tanlov doim sizda"
            subtitle = "Salom AI bepul imkoniyatlarni reklama orqali qo‘llab-quvvatlaydi. Ruxsat bersangiz, sizga mosroq reklamalar ko‘rsatiladi."
            relevantTitle = "Mosroq reklama"
            relevantSubtitle = "Qiziqishlaringizga yaqin takliflar"
            controlTitle = "Siz boshqarasiz"
            controlSubtitle = "Rad etsangiz ham ilova to‘liq ishlaydi"
            continueTitle = "Davom etish"
            footnote = "Keyingi Apple oynasida ruxsat berish yoki rad etishni o‘zingiz tanlaysiz."
        }
    }
}
