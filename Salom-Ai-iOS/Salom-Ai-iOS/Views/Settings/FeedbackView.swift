import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Fikr-mulohaza yuborish")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top)
                
                Text("Taklif va shikoyatlaringizni yozib qoldiring. Biz har bir fikrni o'qib chiqamiz.")
                    .font(.subheadline)
                    .foregroundColor(SalomTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextEditor(text: $content)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .foregroundColor(.white)
                    .frame(height: 200)
                    .padding()
                
                Button {
                    Task {
                        await submitFeedback()
                    }
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Yuborish")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : SalomTheme.Colors.accentPrimary)
                    )
                }
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .alert("Xabar", isPresented: $showAlert) {
            Button("OK") {
                if !isSubmitting { // Only dismiss if success (isSubmitting is false after success)
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func submitFeedback() async {
        isSubmitting = true
        do {
            let _: FeedbackResponse = try await APIClient.shared.request(.sendFeedback(content: content), decodeTo: FeedbackResponse.self)
            await MainActor.run {
                isSubmitting = false
                alertMessage = "Fikr-mulohazangiz uchun rahmat!"
                showAlert = true
                content = ""
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                alertMessage = "Xatolik yuz berdi: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

struct FeedbackResponse: Codable {
    let id: Int
    let content: String
}
