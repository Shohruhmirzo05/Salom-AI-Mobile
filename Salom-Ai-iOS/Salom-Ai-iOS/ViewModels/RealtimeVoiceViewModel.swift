//
//  RealtimeVoiceViewModel.swift
//  Salom-Ai-iOS
//
//  ViewModel for real-time voice conversation
//

import Foundation
import Combine
import AVFoundation
internal import UIKit

@MainActor
class RealtimeVoiceViewModel: ObservableObject {
    @Published var connectionState: RealtimeWebSocketState = .disconnected
    @Published var voiceState: RealtimeVoiceState = .idle
    @Published var messages: [RealtimeMessage] = []
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var isMuted: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var errorMessage: String?
    @Published var showError = false
    
    let wsManager = RealtimeWebSocketManager()
    private let audioManager = RealtimeAudioManager()
    private var cancellables = Set<AnyCancellable>()
    private var wasConnectedBeforeBackground = false
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        setupBindings()
        setupAudioHandling()
        setupSystemObservers()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - System Observers (audio interruptions, route changes, app lifecycle)
    private func setupSystemObservers() {
        let nc = NotificationCenter.default

        // 1. Audio session interruption (phone calls, Siri, alarms)
        let interruptionObs = nc.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

            switch type {
            case .began:
                print("🔕 [RealtimeVM] Audio interrupted (phone/Siri/alarm) — pausing")
                self.audioManager.stopRecording()
                self.audioManager.stopPlayback()
            case .ended:
                let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                if options.contains(.shouldResume) {
                    print("🔔 [RealtimeVM] Audio interruption ended — resuming")
                    if self.connectionState == .connected && self.voiceState == .listening && !self.isMuted {
                        Task { @MainActor in self.startRecording() }
                    }
                }
            @unknown default:
                break
            }
        }
        notificationObservers.append(interruptionObs)

        // 2. Audio route changes (Bluetooth connect/disconnect, headphones)
        let routeObs = nc.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let info = notification.userInfo,
                  let reasonRaw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }

            switch reason {
            case .oldDeviceUnavailable:
                // Headphones unplugged / Bluetooth disconnected — pause to be safe.
                print("🎧 [RealtimeVM] Audio route changed: old device unavailable — pausing")
                self.audioManager.stopRecording()
                self.audioManager.stopPlayback()
            case .newDeviceAvailable, .categoryChange, .override:
                // Continue — just log.
                print("🎧 [RealtimeVM] Audio route changed: \(reason.rawValue)")
            default:
                break
            }
        }
        notificationObservers.append(routeObs)

        // 3. App lifecycle — gracefully tear down on background, reconnect on foreground
        let bgObs = nc.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.wasConnectedBeforeBackground = (self.connectionState == .connected || self.connectionState == .connecting)
            print("📱 [RealtimeVM] App backgrounded; wasConnected=\(self.wasConnectedBeforeBackground) — disconnecting WS")
            self.audioManager.stopRecording()
            self.audioManager.stopPlayback()
            self.wsManager.disconnect()
        }
        notificationObservers.append(bgObs)

        let fgObs = nc.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if self.wasConnectedBeforeBackground {
                print("📱 [RealtimeVM] App foregrounded — reconnecting WS")
                self.wasConnectedBeforeBackground = false
                self.connect()
            }
        }
        notificationObservers.append(fgObs)
    }
    
    private func setupBindings() {
        // WebSocket state
        wsManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
                if case .error(let message) = state {
                    self?.showErrorAlert(message)
                }
            }
            .store(in: &cancellables)
        
        // Voice state
        wsManager.$voiceState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.voiceState = state
                self?.handleVoiceStateChange(state)
            }
            .store(in: &cancellables)
        
        // Messages
        wsManager.$messages
            .receive(on: DispatchQueue.main)
            .assign(to: &$messages)
        
        // Audio recording state
        audioManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        // Audio playback state
        audioManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.isPlaying = isPlaying
                // Auto-resume recording when playback finishes if in listening state
                if !isPlaying && self?.voiceState == .listening {
                    print("🎤 [RealtimeVM] Playback finished, resuming recording")
                    self?.startRecording()
                }
            }
            .store(in: &cancellables)
        
        // Audio level
        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
    }
    
    private func setupAudioHandling() {
        // 1. Send CLEAN audio to WebSocket
        audioManager.onAudioChunk = { [weak self] data in
            // Only send if we are in a state that allows it
            guard self?.voiceState == .listening || self?.voiceState == .speaking else { return }
            self?.wsManager.sendAudioChunk(data)
        }
        
        // Play received audio
        wsManager.onAudioReceived = { [weak self] data in
            self?.audioManager.playAudio(data: data)
        }
        
        // 2. User Started Talking
        audioManager.onSpeechDetected = { [weak self] in
            guard let self = self else { return }
            print("🗣️ [ViewModel] User speaking - interrupting bot")
            
            // If bot was talking, shut it up immediately
            if self.isPlaying {
                self.audioManager.stopPlayback()
                self.wsManager.sendInterruption() // Send "stop" to backend
            }
            
            self.voiceState = .listening // Update UI to show "Listening"
            self.wsManager.sendSpeechStarted()
        }
        
        // 3. User Stopped Talking (Silence)
        audioManager.onSilenceDetected = { [weak self] in
            print("🤫 [ViewModel] User finished - waiting for response")
            // The library already waited for silence, so we can commit immediately
            self?.wsManager.sendEndUtterance() 
            self?.voiceState = .thinking // Update UI to show "Thinking"
        }
    }
    
    private func handleVoiceStateChange(_ state: RealtimeVoiceState) {
        print("🔄 [RealtimeVM] State changed to: \(state.rawValue)")
        
        switch state {
        case .idle:
            audioManager.stopRecording()
            audioManager.stopPlayback()
            
        case .listening:
            // Start recording if not already and not playing audio
            if !audioManager.isRecording && !isPlaying {
                startRecording()
            }
            
        case .transcribing, .thinking:
            // Stop recording, wait for response
            audioManager.stopRecording()
            
        case .speaking:
            // Audio playback handled by onAudioReceived callback
            break
        }
    }
    
    func connect() {
        guard let token = TokenStore.shared.accessToken else {
            showErrorAlert("No authentication token found")
            return
        }
        
        print("🔌 [RealtimeVM] Connecting...")
        Task {
            await wsManager.connect(token: token)
        }
    }
    
    func disconnect() {
        print("🔌 [RealtimeVM] Disconnecting...")
        wsManager.disconnect()
        audioManager.stopRecording()
        audioManager.stopPlayback()
    }
    
    func stopAudio() {
        print("🔇 [RealtimeVM] Stopping audio playback")
        audioManager.stopPlayback()
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        guard !isMuted else {
            print("🔇 [RealtimeVM] Muted, skipping recording")
            return
        }
        
        guard connectionState == .connected else {
            print("⚠️ [RealtimeVM] Not connected, cannot start recording")
            return
        }
        
        guard voiceState == .idle || voiceState == .listening else {
            print("⚠️ [RealtimeVM] Cannot start recording in state: \(voiceState.rawValue)")
            return
        }
        
        print("🎤 [RealtimeVM] Starting recording")
        audioManager.startRecording()
        HapticManager.shared.impact(style: .medium)
    }
    
    func stopRecording() {
        print("🎤 [RealtimeVM] Stopping recording")
        audioManager.stopRecording()
        wsManager.sendEndUtterance()
        HapticManager.shared.impact(style: .light)
    }
    
    func reset() {
        print("🔄 [RealtimeVM] Resetting conversation")
        wsManager.reset()
        audioManager.stopRecording()
        audioManager.stopPlayback()
        HapticManager.shared.impact(style: .soft)
    }
    
    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
        HapticManager.shared.fire(.error)
    }
    
    func dismissError() {
        showError = false
        errorMessage = nil
    }
    
    // MARK: - Voice Preview
    func previewVoice(language: String, voice: String, role: String) async throws {
        print("🔊 [RealtimeVM] Requesting preview for \(voice) (\(role))")
        
        guard let token = TokenStore.shared.accessToken else {
            throw NSError(domain: "RealtimeVM", code: 401, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        // Use REST endpoint for preview to avoid WebSocket connection logic during settings
        let url = URL(string: "https://api.salom-ai.uz/ws/voice/yandex/preview")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "text": getPreviewText(for: language),
            "language": language,
            "voice": voice,
            "role": role
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "RealtimeVM", code: 500, userInfo: [NSLocalizedDescriptionKey: "Preview failed: \(errorMsg)"])
        }
        
        // Play the received audio
        await MainActor.run {
            audioManager.playAudio(data: data)
        }
    }
    
    private func getPreviewText(for language: String) -> String {
        switch language {
        case "uz-UZ": return "Bu ovoz namunasi. Men sizga qanday yordam bera olaman?"
        case "ru-RU": return "Это образец голоса. Чем я могу вам помочь?"
        case "en-US": return "This is a voice preview. How can I help you?"
        default: return "Bu ovoz namunasi."
        }
    }

    // MARK: - Language Helpers
    var currentLanguageFlag: String {
        switch wsManager.currentLanguage {
        case "uz-UZ": return "🇺🇿"
        case "ru-RU": return "🇷🇺"
        case "en-US": return "🇺🇸"
        default: return "🇺🇿"
        }
    }
    
    var currentLanguageName: String {
        switch wsManager.currentLanguage {
        case "uz-UZ": return "O'zbekcha"
        case "ru-RU": return "Русский"
        case "en-US": return "English"
        default: return "O'zbekcha"
        }
    }
}
