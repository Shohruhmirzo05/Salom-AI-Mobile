//
//  CardInputSheet.swift
//  Salom-Ai-iOS
//
//  Card number + expiry input for Click tokenization.
//  Pushed inside NavigationStack from PaywallSheet.
//

import SwiftUI

struct CardInputSheet: View {
    let planCode: String
    let onTokenized: (String, String) -> Void // (requestId, phoneHint)
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.dismissAll) var dismissAll
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var cardNumber = ""
    @State private var expiryDate = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?
    
    private let clickBlue = Color(hex: "0065FF")
    
    enum Field { case card, expiry }
    
    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 26) {
                    header
                    cardForm
                    errorView
                    HStack(spacing: 20) {
                        securityBadge(icon: "lock.shield.fill", text: "SSL himoya")
                        securityBadge(icon: "checkmark.shield.fill", text: "PCI DSS")
                        securityBadge(icon: "eye.slash.fill", text: "Maxfiy")
                    }
                }
                .padding(.top, 25)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focusedField = .card
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("click-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50)
//                    .padding(.top)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomSection
        }
    }
    
    // MARK: - Header
    private var header: some View {
        VStack(spacing: 12) {
            Text("Karta ma'lumotlari")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            
            Text("To'lov xavfsiz Click tizimi orqali amalga oshiriladi")
                .font(.subheadline)
                .foregroundColor(SalomTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Card form
    
    private var cardForm: some View {
        VStack(spacing: 20) {
            // Card number
            VStack(alignment: .leading, spacing: 8) {
                Text("KARTA RAQAMI")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                
                HStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .foregroundColor(focusedField == .card ? clickBlue : .white.opacity(0.3))
                        .animation(.easeInOut(duration: 0.2), value: focusedField)
                    
                    TextField("8600 1234 5678 9012", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                        .focused($focusedField, equals: .card)
                        .onChange(of: cardNumber) { newValue in
                            cardNumber = formatCardNumber(newValue)
                            if cardNumber.filter({ $0.isNumber }).count == 16 {
                                focusedField = .expiry
                            }
                        }
                        .foregroundColor(.white)
                        .font(.body.monospacedDigit())
                }
                .padding(16)
                .background(Color.white.opacity(focusedField == .card ? 0.1 : 0.05))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            focusedField == .card ? clickBlue.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: focusedField)
            }
            
            // Expiry
            VStack(alignment: .leading, spacing: 8) {
                Text("AMAL QILISH MUDDATI")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(focusedField == .expiry ? clickBlue : .white.opacity(0.3))
                        .animation(.easeInOut(duration: 0.2), value: focusedField)
                    
                    TextField("MM/YY", text: $expiryDate)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .expiry)
                        .onChange(of: expiryDate) { newValue in
                            expiryDate = formatExpiry(newValue)
                        }
                        .foregroundColor(.white)
                        .font(.body.monospacedDigit())
                }
                .padding(16)
                .background(Color.white.opacity(focusedField == .expiry ? 0.1 : 0.05))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            focusedField == .expiry ? clickBlue.opacity(0.5) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: focusedField)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Error
    
    @ViewBuilder
    private var errorView: some View {
        if let error = errorMessage {
            VStack(spacing: 12) {
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
                
                Button {
                    withAnimation { errorMessage = nil }
                    focusedField = .card
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Qayta urinish")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(clickBlue)
                }
            }
            .padding(.horizontal, 24)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    // MARK: - Bottom
    
    private var bottomSection: some View {
        VStack(spacing: 16) {
            Button {
                Task { await tokenize() }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Text("Davom etish")
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isValid
                    ? LinearGradient(colors: [clickBlue, Color(hex: "0050DD")], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(isValid ? .white : .gray)
                .cornerRadius(16)
            }
            .disabled(!isValid || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
    
    @ViewBuilder func securityBadge(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Logic
    
    private var isValid: Bool {
        let digits = cardNumber.filter { $0.isNumber }
        let expiryDigits = expiryDate.filter { $0.isNumber }
        return digits.count == 16 && expiryDigits.count == 4
    }
    
    private func tokenize() async {
        isLoading = true
        errorMessage = nil
        focusedField = nil
        
        let digits = cardNumber.filter { $0.isNumber }
        let expiryDigits = expiryDate.filter { $0.isNumber }
        
        if let response = await subscriptionManager.tokenizeCard(cardNumber: digits, expireDate: expiryDigits) {
            HapticManager.shared.fire(.mediumImpact)
            onTokenized(response.requestId, response.phoneHint)
        } else {
            HapticManager.shared.fire(.error)
            withAnimation(.easeInOut(duration: 0.3)) {
                errorMessage = subscriptionManager.lastError ?? "Tokenizatsiya amalga oshmadi. Qayta urinib ko'ring."
            }
        }
        
        isLoading = false
    }
    
    private func formatCardNumber(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        let limited = String(digits.prefix(16))
        var result = ""
        for (i, char) in limited.enumerated() {
            if i > 0 && i % 4 == 0 { result += " " }
            result.append(char)
        }
        return result
    }
    
    private func formatExpiry(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        let limited = String(digits.prefix(4))
        if limited.count > 2 {
            return String(limited.prefix(2)) + "/" + String(limited.dropFirst(2))
        }
        return limited
    }
}

#Preview("Paywall – plans loaded") {
    let manager = SubscriptionManager.shared
    manager.plans = [
        SubscriptionPlan(
            code: "pro_monthly",
            name: "Pro",
            priceUzs: 49_000,
            monthlyMessages: nil,
            monthlyTokens: nil,
            benefits: nil
        )
    ]
    return NavigationStack { PaywallSheet() }
}

#Preview("Paywall – loading") {
    let manager = SubscriptionManager.shared
    manager.plans = []
    manager.isLoading = true
    return NavigationStack { PaywallSheet() }
}
