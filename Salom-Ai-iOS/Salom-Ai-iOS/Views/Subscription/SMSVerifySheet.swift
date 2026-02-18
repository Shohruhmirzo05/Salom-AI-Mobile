//
//  SMSVerifySheet.swift
//  Salom-Ai-iOS
//
//  SMS code verification for Click card tokenization.
//  Pushed inside NavigationStack from CardInputSheet.
//

import SwiftUI

struct SMSVerifySheet: View {
    let requestId: String
    let phoneHint: String
    let planCode: String
    let onSuccess: () -> Void
    let onBack: (() -> Void)?

    init(requestId: String, phoneHint: String, planCode: String, onSuccess: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.requestId = requestId
        self.phoneHint = phoneHint
        self.planCode = planCode
        self.onSuccess = onSuccess
        self.onBack = onBack
    }

    @Environment(\.dismiss) var dismiss
    @Environment(\.dismissAll) var dismissAll
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var smsCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var timeRemaining = 300
    @State private var timerActive = true
    @State private var timer: Timer?
    @State private var successScale: CGFloat = 0.5
    @FocusState private var isCodeFocused: Bool

    private let clickBlue = Color(hex: "0065FF")

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showSuccess {
                    successView
                        .transition(.opacity.combined(with: .scale))
                } else {
                    inputView
                }
            }
        }
        .onAppear {
            startTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isCodeFocused = true
            }
        }
        .onDisappear { timer?.invalidate() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("click-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50)
            }
        }
    }

    // MARK: - Timer
    private func startTimer() {
        timerActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard timerActive else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
            }
        }
    }

    // MARK: - Input view

    private var inputView: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
//                    ZStack {
//                        Circle()
//                            .fill(
//                                LinearGradient(
//                                    colors: [clickBlue.opacity(0.2), clickBlue.opacity(0.05)],
//                                    startPoint: .top, endPoint: .bottom
//                                )
//                            )
//                            .frame(width: 76, height: 76)
//
//                        Image(systemName: "ellipsis.message.fill")
//                            .font(.system(size: 30))
//                            .foregroundColor(clickBlue)
//                    }

                    Text("SMS kodni kiriting")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)

                    if !phoneHint.isEmpty {
                        Text("Kod \(phoneHint) raqamiga yuborildi")
                            .font(.subheadline)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                    }
                }
                .padding(.top, 16)

                TextField("000000", text: $smsCode)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .focused($isCodeFocused)
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isCodeFocused ? clickBlue.opacity(0.5) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, 48)
                    .onChange(of: smsCode) { newValue in
                        smsCode = String(newValue.filter { $0.isNumber }.prefix(6))
                    }

                timerView
                errorActionView
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Verify button + footer
            VStack(spacing: 16) {
                Button {
                    Task { await verify() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                            Text("Tekshirilmoqda...")
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Tasdiqlash")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        smsCode.count >= 4 && !isLoading
                            ? LinearGradient(colors: [clickBlue, Color(hex: "0050DD")], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(smsCode.count >= 4 && !isLoading ? .white : .gray)
                    .cornerRadius(16)
                }
                .disabled(smsCode.count < 4 || isLoading)
                .padding(.horizontal, 24)

                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.caption2)
                    Text("Barcha ma'lumotlar shifrlangan")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Timer view

    @ViewBuilder
    private var timerView: some View {
        if timerActive {
            if timeRemaining > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Kod amal qilish muddati: \(timeRemaining / 60):\(String(format: "%02d", timeRemaining % 60))")
                        .font(.subheadline)
                }
                .foregroundColor(timeRemaining <= 60 ? .orange : SalomTheme.Colors.textSecondary)
            } else {
                Text("Kod muddati tugadi")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Error with actions

    @ViewBuilder
    private var errorActionView: some View {
        if let error = errorMessage {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )

                HStack(spacing: 16) {
                    Button {
                        withAnimation {
                            errorMessage = nil
                            smsCode = ""
                            timerActive = true
                            isCodeFocused = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Qayta urinish")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(clickBlue)
                    }

                    if onBack != nil {
                        Button {
                            onBack?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "creditcard")
                                Text("Kartani o'zgartirish")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(successScale)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                    .scaleEffect(successScale)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    successScale = 1.0
                }
            }

            VStack(spacing: 8) {
                Text("Muvaffaqiyatli!")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)

                Text("Obuna faollashtirildi va karta saqlandi")
                    .font(.body)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                onSuccess()
            } label: {
                HStack {
                    Text("Tayyor")
                        .fontWeight(.bold)
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Verify

    private func verify() async {
        isLoading = true
        errorMessage = nil
        timerActive = false
        isCodeFocused = false

        guard let code = Int(smsCode) else {
            HapticManager.shared.fire(.error)
            withAnimation { errorMessage = "Noto'g'ri kod formati" }
            isLoading = false
            timerActive = true
            return
        }

        if let response = await subscriptionManager.verifySMS(requestId: requestId, smsCode: code, planCode: planCode) {
            if response.success {
                HapticManager.shared.fire(.success)
                await subscriptionManager.checkSubscriptionStatus()
                await subscriptionManager.fetchSavedCards()
                withAnimation(.easeInOut(duration: 0.4)) { showSuccess = true }
            } else {
                HapticManager.shared.fire(.error)
                withAnimation { errorMessage = "Tasdiqlash amalga oshmadi" }
                timerActive = true
            }
        } else {
            HapticManager.shared.fire(.error)
            withAnimation {
                errorMessage = subscriptionManager.lastError ?? "SMS kod noto'g'ri yoki muddati o'tgan"
            }
            timerActive = true
        }

        isLoading = false
    }
}
