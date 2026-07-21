//
//  AuthViewModel.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn
internal import UIKit
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var errorMessage: String?
    @Published var isLoadingGoogle: Bool = false
    @Published var isLoadingApple: Bool = false

    // Telegram "login via bot code" (phone → open bot → type code)
    @Published var isLoadingTelegram: Bool = false
    @Published var showTelegramSheet: Bool = false
    @Published var tgStepCode: Bool = false        // false = phone step, true = code step
    private var tgToken: String?
    private(set) var tgBotUrl: String?

    private let client = APIClient.shared
    private let session = SessionManager.shared
    
    func signInWithGoogle() {
        print("🔵 [Google Auth] Starting Google Sign-In flow...")
        SubscriptionManager.shared.resetPaymentRecovery()
        
        guard let presenting = Self.presentingViewController() else {
            print("❌ [Google Auth] Failed: No presenting view controller")
            errorMessage = String.appLocalized("Ilovani qayta ishga tushiring (controller topilmadi).")
            return
        }
        print("✅ [Google Auth] Presenting view controller found")
        
        if let clientID = Bundle.main.infoDictionary?["GOOGLE_CLIENT_ID"] as? String {
            print("✅ [Google Auth] Client ID loaded: \(clientID.prefix(20))...")
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            print("❌ [Google Auth] WARNING: No GOOGLE_CLIENT_ID in Info.plist")
        }
        
        isLoadingGoogle = true
        errorMessage = nil
        print("🔵 [Google Auth] Presenting Google Sign-In UI...")
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { [weak self] result, error in
            guard let self else {
                print("❌ [Google Auth] Self deallocated")
                return
            }

            Task { @MainActor in
                defer {
                    self.isLoadingGoogle = false
                    print("🔵 [Google Auth] Loading state cleared")
                }

                if let error = error {
                    print("❌ [Google Auth] Sign-in error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    return
                }

                print("✅ [Google Auth] User signed in with Google")

                guard let idToken = result?.user.idToken?.tokenString else {
                    print("❌ [Google Auth] Failed to get ID token")
                    self.errorMessage = String.appLocalized("Google ID token olinmadi.")
                    return
                }

                // Extract name and email from Google profile
                let googleName = result?.user.profile?.name ?? ""
                let googleEmail = result?.user.profile?.email ?? ""
                print("✅ [Google Auth] Name: \(googleName), Email: \(googleEmail)")

                print("✅ [Google Auth] ID token received: \(idToken.prefix(30))...")
                print("🔵 [Google Auth] Starting token exchange with backend...")
                await self.exchangeOAuthToken(idToken, provider: .google, displayName: googleName, email: googleEmail)
            }
        }
    }
    
    func requestSignInWithApple(_ request: ASAuthorizationAppleIDRequest) {
        print("🍎 [Apple Auth] Configuring Apple Sign-In request...")
        SubscriptionManager.shared.resetPaymentRecovery()
        request.requestedScopes = [.fullName, .email]
        print("✅ [Apple Auth] Requested scopes: fullName, email")
    }
    
    func signInWithApple(_ result: Result<ASAuthorization, Error>) {
        print("🍎 [Apple Auth] Apple Sign-In callback received")
        
        switch result {
        case .success(let auth):
            print("✅ [Apple Auth] Authorization successful")
            
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ [Apple Auth] Failed to get Apple ID credential")
                errorMessage = String.appLocalized("Apple credential olinmadi.")
                return
            }
            print("✅ [Apple Auth] Apple ID credential received")
            
            guard let tokenData = credential.identityToken else {
                print("❌ [Apple Auth] No identity token in credential")
                errorMessage = String.appLocalized("Apple token olinmadi.")
                return
            }
            
            guard let token = String(data: tokenData, encoding: .utf8) else {
                print("❌ [Apple Auth] Failed to decode token data")
                errorMessage = String.appLocalized("Apple token decode qilishda xatolik.")
                return
            }
            
            print("✅ [Apple Auth] Identity token decoded: \(token.prefix(30))...")
            
            // Extract name and email from Apple credential (only available on first sign-in)
            let appleEmail = credential.email ?? ""
            let firstName = credential.fullName?.givenName ?? ""
            let lastName = credential.fullName?.familyName ?? ""
            let appleName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
            if !appleEmail.isEmpty { print("✅ [Apple Auth] User email: \(appleEmail)") }
            if !appleName.isEmpty { print("✅ [Apple Auth] User name: \(appleName)") }

            isLoadingApple = true
            print("🍎 [Apple Auth] Starting token exchange with backend...")

            Task { @MainActor in
                await exchangeOAuthToken(token, provider: .apple, displayName: appleName, email: appleEmail)
                isLoadingApple = false
            }
            
        case .failure(let error):
            print("❌ [Apple Auth] Authorization failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Telegram login (phone → open bot → code)

    func openTelegramLogin() {
        SubscriptionManager.shared.resetPaymentRecovery()
        errorMessage = nil
        tgStepCode = false
        tgToken = nil
        tgBotUrl = nil
        showTelegramSheet = true
    }

    func startTelegramCode(phone: String) async {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { errorMessage = String.appLocalized("Telefon raqamingizni kiriting."); return }
        isLoadingTelegram = true
        errorMessage = nil
        do {
            let resp = try await client.request(
                .telegramCodeStart(phone: trimmed),
                decodeTo: TelegramCodeStartResponse.self
            )
            tgToken = resp.token
            tgBotUrl = resp.botUrl
            tgStepCode = true
            if let url = URL(string: resp.botUrl) {
                await UIApplication.shared.open(url)
            }
        } catch {
            errorMessage = String.appLocalized("Xatolik. Raqamni tekshirib, qayta urinib ko‘ring.")
        }
        isLoadingTelegram = false
    }

    func openBot() {
        if let s = tgBotUrl, let url = URL(string: s) {
            Task { await UIApplication.shared.open(url) }
        }
    }

    func verifyTelegramCode(code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token = tgToken else { errorMessage = String.appLocalized("Iltimos, qaytadan boshlang."); return }
        guard trimmed.count >= 4 else { errorMessage = String.appLocalized("Botdan olgan kodni kiriting."); return }
        isLoadingTelegram = true
        errorMessage = nil
        do {
            let tokens = try await client.request(
                .telegramCodeVerify(token: token, code: trimmed),
                decodeTo: TokenPair.self
            )
            TokenStore.shared.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            showTelegramSheet = false
            session.setAuthenticated()
        } catch {
            errorMessage = String.appLocalized("Kod noto‘g‘ri yoki muddati tugagan. Qayta urinib ko‘ring.")
        }
        isLoadingTelegram = false
    }

    private func exchangeOAuthToken(_ token: String, provider: OAuthProvider, displayName: String = "", email: String = "") async {
        print("🔐 [\(provider.displayName)] Starting OAuth token exchange...")
        print("🔐 [\(provider.displayName)] Token length: \(token.count) characters")

        errorMessage = nil

        do {
            print("🔐 [\(provider.displayName)] Sending ID token directly to /auth/oauth/verify...")

            let tokens = try await client.request(
                .oauthVerify(provider: provider, idToken: token),
                decodeTo: TokenPair.self
            )
            print("✅ [\(provider.displayName)] Backend returned access & refresh tokens")
            print("✅ [\(provider.displayName)] Access token: \(tokens.accessToken.prefix(30))...")
            print("✅ [\(provider.displayName)] Refresh token: \(tokens.refreshToken.prefix(30))...")

            print("💾 [\(provider.displayName)] Saving tokens to keychain...")
            TokenStore.shared.save(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
            print("✅ [\(provider.displayName)] Tokens saved successfully")

            // Save name/email from OAuth provider immediately (before backend call)
            if !displayName.isEmpty {
                UserDefaults.standard.set(displayName, forKey: AppStorageKeys.displayName)
                print("✅ [\(provider.displayName)] Saved display name: \(displayName)")
            }
            if !email.isEmpty {
                UserDefaults.standard.set(email, forKey: AppStorageKeys.userEmail)
            }

            // Fetch user info from backend and update stored name
            print("👤 [\(provider.displayName)] Fetching user info from backend...")
            Task.detached {
                do {
                    let user = try await self.client.request(.oauthUser, decodeTo: OAuthUser.self)
                    print("✅ [\(provider.displayName)] User info fetched: \(user.email ?? "no email"), name: \(user.displayName ?? "nil")")
                    await MainActor.run {
                        // Prefer backend display_name; fall back to email-derived name
                        if let backendName = user.displayName, !backendName.isEmpty {
                            UserDefaults.standard.set(backendName, forKey: AppStorageKeys.displayName)
                        } else {
                            let current = UserDefaults.standard.string(forKey: AppStorageKeys.displayName) ?? ""
                            if current.isEmpty, let emailVal = user.email {
                                let derived = emailVal.components(separatedBy: "@").first ?? emailVal
                                UserDefaults.standard.set(derived, forKey: AppStorageKeys.displayName)
                            }
                        }
                        if let backendEmail = user.email, !backendEmail.isEmpty {
                            UserDefaults.standard.set(backendEmail, forKey: AppStorageKeys.userEmail)
                        }
                    }
                } catch {
                    print("⚠️ [\(provider.displayName)] Failed to fetch user info: \(error.localizedDescription)")
                }
            }

            // Set authenticated state
            print("🎉 [\(provider.displayName)] Setting authenticated state...")
            await MainActor.run {
                session.setAuthenticated()
                print("✅ [\(provider.displayName)] User is now authenticated!")
            }
            
        } catch {
            print("❌ [\(provider.displayName)] Token exchange failed!")
            print("❌ [\(provider.displayName)] Error: \(error.localizedDescription)")
            if let apiError = error as? APIError {
                print("❌ [\(provider.displayName)] API Error details: \(apiError)")
            }
            await MainActor.run {
                errorMessage = String.appLocalized("Kirish xatosi: ") + error.localizedDescription
                print("❌ [\(provider.displayName)] Error message shown to user")
            }
        }
    }
    
    private static func presentingViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            BackgroundLayer()
            
            VStack(spacing: 24) {
                Header()
                
                Spacer(minLength: 16)
                OAuthButtons()
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(SalomTheme.Colors.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                }
                
                Spacer()
                
                FooterButtons()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 20)
        }
        .sheet(isPresented: $viewModel.showTelegramSheet) {
            TelegramLoginSheet(viewModel: viewModel)
        }
    }

    // MARK: - Components
    
    @ViewBuilder
    private func BackgroundLayer() -> some View {
        SalomTheme.Gradients.background
            .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func Header() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keling, kirib olamiz")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textPrimary)

            Text("Google, Apple yoki Telegram orqali tezda kiring.")
                .font(.subheadline)
                .foregroundColor(SalomTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func OAuthButtons() -> some View {
        VStack(spacing: 14) {
            Button {
                HapticManager.shared.fire(.lightImpact)
                viewModel.signInWithGoogle()
            } label: {
                HStack {
                    Image(.googleIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.textPrimary)
                    Text("Google orqali kirish")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(SalomTheme.Colors.textPrimary.opacity(viewModel.isLoadingGoogle ? 0.6 : 1))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SalomTheme.Colors.surface)
                )
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(SalomTheme.Colors.border))
            }
            .overlay(alignment: .trailing) {
                if viewModel.isLoadingGoogle {
                    ProgressView().tint(SalomTheme.Colors.accentPrimary).padding(.trailing, 16)
                }
            }
            .disabled(viewModel.isLoadingGoogle || viewModel.isLoadingApple)
            
            SignInWithAppleButton(.continue, onRequest: viewModel.requestSignInWithApple, onCompletion: viewModel.signInWithApple)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(SalomTheme.Gradients.accent)
                        HStack(spacing: 9) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .semibold))
                            Text(String.appLocalized("Apple orqali kirish"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)

                        if viewModel.isLoadingApple {
                            Color.black.opacity(0.4)
                            ProgressView().tint(.white)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .accessibilityLabel(Text(String.appLocalized("Apple orqali kirish")))
                .disabled(viewModel.isLoadingGoogle || viewModel.isLoadingApple)

            Button {
                HapticManager.shared.fire(.lightImpact)
                viewModel.openTelegramLogin()
            } label: {
                HStack {
                    Image(.telegramLogo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                    Text("Telegram orqali kirish")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.16, green: 0.62, blue: 0.85))
                )
            }
            .disabled(viewModel.isLoadingGoogle || viewModel.isLoadingApple)
        }
        .glassCard(cornerRadius: 26)
    }
    
    @ViewBuilder
    private func FooterButtons() -> some View {
        VStack(spacing: 12) {
            Text("Kirish orqali siz xizmat shartlari va maxfiylik siyosatiga rozilik bildirasiz.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundColor(SalomTheme.Colors.textSecondary)
                .padding(.horizontal, 8)
        }
    }
}

// MARK: - Telegram login sheet (phone → open bot → code)

struct TelegramLoginSheet: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var phone: String = ""
    @State private var code: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(SalomTheme.Colors.textTertiary.opacity(0.55))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Telegram orqali kirish")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(SalomTheme.Colors.textPrimary)
                    Text(viewModel.tgStepCode
                         ? "Salom AI botini oching, «Start» ni bosing va bot bergan 6 xonali kodni kiriting."
                         : "Telegram raqamingizni kiriting. So‘ng botni ochib «Start» ni bosasiz.")
                        .font(.subheadline)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !viewModel.tgStepCode {
                    TextField("+998 90 123 45 67", text: $phone)
                        .keyboardType(.phonePad)
                        .focused($focused)
                        .font(.system(size: 18, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(SalomTheme.Colors.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SalomTheme.Colors.border))
                        .foregroundColor(SalomTheme.Colors.textPrimary)

                    primaryButton("Davom etish") {
                        Task { await viewModel.startTelegramCode(phone: phone) }
                    }
                } else {
                    Button {
                        viewModel.openBot()
                    } label: {
                        HStack {
                            Image(.telegramLogo).resizable().scaledToFit().frame(width: 20, height: 20)
                            Text("Botni ochish").font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.16, green: 0.62, blue: 0.85)))
                    }

                    TextField("• • • • • •", text: $code)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .font(.system(size: 24, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(SalomTheme.Colors.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SalomTheme.Colors.border))
                        .foregroundColor(SalomTheme.Colors.textPrimary)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.filter(\.isNumber).prefix(6))
                        }

                    primaryButton("Kirish") {
                        Task { await viewModel.verifyTelegramCode(code: code) }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(SalomTheme.Colors.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
        .onAppear { focused = true }
    }

    @ViewBuilder
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(viewModel.isLoadingTelegram ? 0 : 1)
                if viewModel.isLoadingTelegram {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.16, green: 0.62, blue: 0.85)))
        }
        .disabled(viewModel.isLoadingTelegram)
    }
}
