//
//  VoiceView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI
import Combine
import AVFoundation

@MainActor
final class VoiceViewModel: ObservableObject {
    struct VoiceMessage: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let isUser: Bool
        let timestamp = Date()
    }

    @Published var isRecording: Bool = false
    @Published var isProcessing: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var messages: [VoiceMessage] = []
    @Published var errorMessage: String?
    @Published var conversationId: Int?
    
    private let audioRecorder = AudioRecorder()
    private var audioPlayer: AVAudioPlayer?
    private var cancellables = Set<AnyCancellable>()
    private let client = APIClient.shared
    
    init() {
        print("🎤 [VoiceViewModel] Initializing...")
        
        audioRecorder.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording in
                print("🎤 [VoiceViewModel] Recording state changed: \(isRecording)")
                self?.isRecording = isRecording
            }
            .store(in: &cancellables)
        
        audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        audioRecorder.$recordingURL
            .receive(on: RunLoop.main)
            .sink { [weak self] url in
                if let url = url {
                    print("🎤 [VoiceViewModel] Recording completed at: \(url.path)")
                    self?.sendVoiceQuery(audioURL: url)
                }
            }
            .store(in: &cancellables)
        
        print("🎤 [VoiceViewModel] Initialization complete")
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            print("🔊 [VoiceViewModel] Audio session configured: playAndRecord, defaultToSpeaker")
        } catch {
            print("❌ [VoiceViewModel] Failed to configure audio session: \(error)")
        }
    }
    
    
    func startRecording() {
        print("🎤 [VoiceViewModel] startRecording called")
        
        guard !isRecording && !isProcessing else {
            print("🎤 [VoiceViewModel] Already recording or processing, ignoring")
            return
        }
        
        Task {
            if await audioRecorder.requestPermission() {
                print("🎤 [VoiceViewModel] Microphone permission granted")
                audioRecorder.startRecording()
                print("🎤 [VoiceViewModel] Recording started")
            } else {
                print("❌ [VoiceViewModel] Microphone permission denied")
                await MainActor.run {
                    errorMessage = String.appLocalized("Mikrofon ruxsati berilmagan")
                }
            }
        }
    }
    
    func stopRecording() {
        print("🎤 [VoiceViewModel] stopRecording called")
        
        guard isRecording else {
            print("🎤 [VoiceViewModel] Not recording, ignoring")
            return
        }
        
        audioRecorder.stopRecording()
    }
    
    // Legacy method for compatibility
    func toggleRecording() {
        print("🎤 [VoiceViewModel] toggleRecording called, current state: \(isRecording)")
        
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func sendVoiceQuery(audioURL: URL) {
        print("🎤 [VoiceViewModel] sendVoiceQuery started")
        print("🎤 [VoiceViewModel] Audio URL: \(audioURL.path)")
        
        Task {
            await MainActor.run { 
                isProcessing = true 
                print("🎤 [VoiceViewModel] Processing started")
            }
            
            do {
                let audioData = try Data(contentsOf: audioURL)
                print("🎤 [VoiceViewModel] Audio data loaded: \(audioData.count) bytes")
                
                // Create multipart form data
                let boundary = UUID().uuidString
                var body = Data()
                
                // Add file
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"voice.m4a\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
                body.append(audioData)
                body.append("\r\n".data(using: .utf8)!)
                
                // Add conversation_id if exists
                if let convId = conversationId {
                    print("🎤 [VoiceViewModel] Adding conversation_id: \(convId)")
                    body.append("--\(boundary)\r\n".data(using: .utf8)!)
                    body.append("Content-Disposition: form-data; name=\"conversation_id\"\r\n\r\n".data(using: .utf8)!)
                    body.append("\(convId)\r\n".data(using: .utf8)!)
                }
                
                // Close boundary
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                
                print("🎤 [VoiceViewModel] Multipart body created: \(body.count) bytes")
                
                // Make request
                let urlString = "\(APIClient.shared.baseURL)/voice/yandex/query"
                print("➡️ [VoiceViewModel] POST \(urlString)")
                
                var request = URLRequest(url: URL(string: urlString)!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(TokenStore.shared.accessToken ?? "")", forHTTPHeaderField: "Authorization")
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
                
                print("🎤 [VoiceViewModel] Request headers: \(request.allHTTPHeaderFields ?? [:])")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ [VoiceViewModel] Invalid response type")
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                print("⬅️ [VoiceViewModel] Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    print("⬅️ [VoiceViewModel] Response body: \(responseString)")
                    
                    let decoder = JSONDecoder()
                    // decoder.keyDecodingStrategy = .convertFromSnakeCase // Removed as we use explicit CodingKeys
                    let result = try decoder.decode(VoiceQueryResponse.self, from: data)
                    
                    print("✅ [VoiceViewModel] Decoded response:")
                    print("   - User text: \(result.userText)")
                    print("   - AI text: \(result.aiText)")
                    print("   - Conversation ID: \(result.conversationId)")
                    print("   - Audio length: \(result.audio.count) chars (base64)")
                    
                    await MainActor.run {
                        // Append user message
                        if !result.userText.isEmpty {
                            self.messages.append(VoiceMessage(text: result.userText, isUser: true))
                        }
                        
                        // Append AI message
                        if !result.aiText.isEmpty {
                            self.messages.append(VoiceMessage(text: result.aiText, isUser: false))
                        }
                        
                        self.conversationId = result.conversationId
                        
                        // Play audio response
                        if let audioData = Data(base64Encoded: result.audio) {
                            print("🔊 [VoiceViewModel] Playing audio response: \(audioData.count) bytes")
                            self.playAudio(data: audioData)
                        } else {
                            print("❌ [VoiceViewModel] Failed to decode base64 audio")
                        }
                    }
                } else {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ [VoiceViewModel] HTTP \(httpResponse.statusCode): \(errorText)")
                    throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
                }
                
            } catch {
                print("❌ [VoiceViewModel] Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = String.appLocalized("Xatolik: ") + error.localizedDescription
                }
            }
            
            await MainActor.run {
                self.isProcessing = false
                print("🎤 [VoiceViewModel] Processing complete")
            }
        }
    }
    
    private func playAudio(data: Data) {
        print("🔊 [VoiceViewModel] playAudio called with \(data.count) bytes")
        
        // Save to temp file first for better compatibility
        let tempDir = FileManager.default.temporaryDirectory
        let audioURL = tempDir.appendingPathComponent("response_\(UUID().uuidString).mp3")
        
        do {
            try data.write(to: audioURL)
            print("🔊 [VoiceViewModel] Audio saved to: \(audioURL.path)")
            
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            let success = audioPlayer?.play() ?? false
            print("🔊 [VoiceViewModel] Audio playback \(success ? "started" : "failed")")
            
            if success {
                print("🔊 [VoiceViewModel] Audio duration: \(audioPlayer?.duration ?? 0) seconds")
            }
        } catch {
            print("❌ [VoiceViewModel] Audio playback error: \(error)")
            print("❌ [VoiceViewModel] Error details: \(error.localizedDescription)")
        }
    }
}

struct VoiceQueryResponse: Codable {
    let conversationId: Int
    let userText: String
    let aiText: String
    let audio: String // Base64
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userText = "user_text"
        case aiText = "ai_text"
        case audio = "audio_base64"
    }
}

struct VoiceView: View {
    @StateObject private var viewModel = VoiceViewModel()
    @State private var pulse: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .overlay(
                    RadialGradient(
                        colors: [
                            SalomTheme.Colors.surfaceMuted.opacity(0.45),
                            Color.clear
                        ],
                        center: .topTrailing,
                        startRadius: 60,
                        endRadius: 520
                    )
                )
                .overlay(
                    RadialGradient(
                        colors: [
                            SalomTheme.Colors.accentPrimary.opacity(0.24),
                            .clear
                        ],
                        center: .bottomLeading,
                        startRadius: 40,
                        endRadius: 420
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isProcessing {
                                HStack {
                                    ProgressView()
                                        .tint(SalomTheme.Colors.accentPrimary)
                                    Text("Javob tayyorlanmoqda...")
                                        .font(.caption)
                                        .foregroundColor(SalomTheme.Colors.textSecondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("processing")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages) { _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Controls
                VStack(spacing: 12) {
//                    if let error = viewModel.errorMessage {
//                        Text(error)
//                            .font(.caption)
//                            .foregroundColor(.red)
//                            .padding(.horizontal)
//                            .multilineTextAlignment(.center)
//                    }
                    
                    MicButton()
                    
                    Text(viewModel.isRecording ? "Gapiring..." : (viewModel.isProcessing ? "Kuting..." : "Bosib turing"))
                        .font(.subheadline)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .padding(.bottom, 12)
            }
        }
        .alert("Xatolik", isPresented: .constant(viewModel.errorMessage != nil), presenting: viewModel.errorMessage) { _ in
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: { error in
            Text(error)
        }
    }
    
    
    @ViewBuilder
    private func MicButton() -> some View {
        ZStack {
            if viewModel.isRecording {
                PulsingCircle()
            }
            
            ZStack {
                Circle()
                    .fill(
                        viewModel.isRecording ?
                        LinearGradient(
                            colors: [Color.red, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                            LinearGradient(
                                colors: [SalomTheme.Colors.accentPrimary, SalomTheme.Colors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(SalomTheme.Colors.border, lineWidth: 2)
                    )
                    .shadow(
                        color: (viewModel.isRecording ? Color.red : SalomTheme.Colors.accentPrimary).opacity(0.4),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                
                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(SalomTheme.Colors.onAccent)
            }
            .frame(width: 120, height: 120)
            .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isRecording)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !viewModel.isRecording && !viewModel.isProcessing {
                            HapticManager.shared.fire(.mediumImpact)
                            viewModel.startRecording()
                        }
                    }
                    .onEnded { _ in
                        if viewModel.isRecording {
                            HapticManager.shared.fire(.warning)
                            viewModel.stopRecording()
                        }
                    }
            )
        }
        .frame(height: 180)
    }
    
    @ViewBuilder func PulsingCircle() -> some View {
        Circle()
            .stroke(Color.red.opacity(0.4), lineWidth: 3)
            .frame(width: 170, height: 170)
            .scaleEffect(pulse ? 1.2 : 0.8)
            .opacity(pulse ? 0.0 : 1.0)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
    }

}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    let message: VoiceViewModel.VoiceMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(SalomTheme.Colors.onMedia)
                    .cornerRadius(16)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                Text(message.text)
                    .padding()
                    .background(SalomTheme.Colors.surface)
                    .foregroundColor(SalomTheme.Colors.textPrimary)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(SalomTheme.Colors.border))
                    .cornerRadius(16)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                Spacer()
            }
        }
    }
}
