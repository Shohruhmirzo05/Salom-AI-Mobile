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

    // Pre-connect eligibility — set by `preflight()` before any WS attempt.
    // When non-nil, the View routes to the paywall instead of dialing OpenAI.
    @Published var blockedReason: String? = nil
    @Published var preflightInFlight = false
    
    // Provider is chosen by RealtimeProviderConfig (default: .openai).
    // The protocol abstracts away whether we're talking to the Yandex pipeline
    // or the OpenAI Realtime proxy — call sites below are provider-agnostic.
    let wsManager: any RealtimeVoiceProviding = RealtimeProviderConfig.makeProvider()
    // Mic sample rate matches the active provider:
    //   • Yandex STT  → 16 kHz PCM16
    //   • OpenAI Realtime → 24 kHz PCM16
    private let audioManager = RealtimeAudioManager(
        sampleRate: RealtimeProviderConfig.current == .openai ? 24000 : 16000
    )
    private var cancellables = Set<AnyCancellable>()
    private var wasConnectedBeforeBackground = false
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        // Share the audio manager's engine with the OpenAI provider so VPIO
        // sees both mic input and speaker output — required for proper AEC.
        if let openai = wsManager as? OpenAIRealtimeManager {
            openai.attach(audioManager: audioManager)
        }
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
        // WebSocket state (protocol-typed — works for either provider)
        wsManager.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.connectionState = state
                if case .error(let message) = state {
                    // The server sends a localized Uzbek error message on
                    // quota / subscription refusals (e.g. "Siz xabar limitiga
                    // yetdingiz. Rejangizni yangilang."). Surface it as a
                    // paywall trigger by routing through blockedReason — that
                    // way the View's existing block-alert + paywall flow
                    // fires whether the refusal came at preflight time OR
                    // mid-session via the WS gate.
                    if Self.looksLikeQuotaRefusal(message) {
                        self.blockedReason = message
                    } else {
                        self.showErrorAlert(message)
                    }
                }
            }
            .store(in: &cancellables)

        // Voice state
        wsManager.voiceStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.voiceState = state
                self?.handleVoiceStateChange(state)
            }
            .store(in: &cancellables)

        // Messages
        wsManager.messagesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                self?.messages = msgs
            }
            .store(in: &cancellables)
        
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
        
        // Audio level — visualizer feed.
        //
        // For OpenAI: when the assistant is speaking we want the visualizer
        // to pulse to its output voice, not the mic. We combine the mic
        // level with the OpenAI player's output level and pick the one
        // matching the current voice state.
        if wsManager is OpenAIRealtimeManager {
            // Visualizer feed: mic level during listening, streaming player
            // level during speaking. Both come from the shared audioManager
            // now that engines are consolidated.
            Publishers.CombineLatest3(
                audioManager.$audioLevel,
                audioManager.$streamingPlayerLevel,
                $voiceState
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] micLevel, outLevel, state in
                self?.audioLevel = (state == .speaking) ? outLevel : micLevel
            }
            .store(in: &cancellables)
        } else {
            audioManager.$audioLevel
                .receive(on: DispatchQueue.main)
                .assign(to: &$audioLevel)
        }
    }
    
    private func setupAudioHandling() {
        // 1. Forward mic chunks to whichever provider is active.
        audioManager.onAudioChunk = { [weak self] data in
            guard let self = self else { return }
            if RealtimeProviderConfig.current == .openai {
                // OpenAI: stream every chunk; server VAD handles turn-taking.
                self.wsManager.sendAudioChunk(data)
            } else {
                // Yandex: only stream when we're in an utterance-active state.
                guard self.voiceState == .listening || self.voiceState == .speaking else { return }
                self.wsManager.sendAudioChunk(data)
            }
        }

        // Yandex provider plays MP3 chunks via the audio manager.
        // OpenAI provider plays audio inside its own streaming engine and
        // never invokes this callback.
        wsManager.onAudioReceived = { [weak self] data in
            self?.audioManager.playAudio(data: data)
        }

        // 2. User Started Talking — Yandex-only barge-in path.
        // OpenAI's server VAD detects speech on the continuous mic stream
        // and interrupts the response itself (interrupt_response: true).
        audioManager.onSpeechDetected = { [weak self] in
            guard let self = self else { return }
            guard RealtimeProviderConfig.current == .yandex else { return }

            print("🗣️ [ViewModel] User speaking - interrupting bot")
            if self.isPlaying {
                self.audioManager.stopPlayback()
                self.wsManager.sendInterruption()
            }
            self.voiceState = .listening
            self.wsManager.sendSpeechStarted()
        }

        // 3. User Stopped Talking — Yandex-only commit path.
        audioManager.onSilenceDetected = { [weak self] in
            guard let self = self else { return }
            guard RealtimeProviderConfig.current == .yandex else { return }

            print("🤫 [ViewModel] User finished - waiting for response")
            self.wsManager.sendEndUtterance()
            self.voiceState = .thinking
        }
    }
    
    private func handleVoiceStateChange(_ state: RealtimeVoiceState) {
        print("🔄 [RealtimeVM] State changed to: \(state.rawValue)")

        // OpenAI uses server-side VAD on a continuous mic stream — the mic
        // must stay on for the entire session so OpenAI can detect both
        // end-of-turn and mid-response barge-in. Voice state is purely UI;
        // the only mic transition we handle is full teardown on .idle.
        // iOS hardware echo cancellation (.voiceChat mode) prevents the
        // assistant's voice from being re-captured as user speech.
        if RealtimeProviderConfig.current == .openai {
            switch state {
            case .idle:
                audioManager.stopRecording()
            case .listening:
                if !audioManager.isRecording && !isMuted && connectionState == .connected {
                    startRecording()
                }
            case .transcribing, .thinking, .speaking:
                // Keep mic running — server VAD listens for barge-in.
                break
            }
            return
        }

        // Yandex provider: explicit utterance boundaries, mic pauses during AI turn.
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

    /// Pre-connect eligibility check.
    /// Returns true if the user is allowed to start a voice session right now.
    /// On false, `blockedReason` is set to a user-facing localized message.
    /// Fails OPEN on network/server errors (the WS gate is the source of truth).
    func preflight() async -> Bool {
        preflightInFlight = true
        blockedReason = nil
        defer { preflightInFlight = false }

        guard let token = TokenStore.shared.accessToken else {
            // Auth issue — let the normal connect path surface it.
            return true
        }

        do {
            let url = URL(string: "https://api.salom-ai.uz/realtime/voice-status")!
            var req = URLRequest(url: url)
            req.timeoutInterval = 8
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: req)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let allowed = json["allowed"] as? Bool else {
                print("⚠️ [RealtimeVM] Preflight: unexpected response — failing open")
                return true
            }

            if allowed {
                print("✅ [RealtimeVM] Preflight passed")
                return true
            }

            let reason = (json["reason"] as? String) ?? "voice_disabled"
            let used = (json["used_minutes"] as? Double) ?? 0
            let limit = (json["limit_minutes"] as? Int) ?? 0
            let resetISO = json["reset_at"] as? String
            print("🚫 [RealtimeVM] Preflight blocked: \(reason) (\(used)/\(limit) min) reset=\(resetISO ?? "?")")
            blockedReason = Self.localizedBlockMessage(
                for: reason,
                used: used,
                limit: limit,
                resetISO: resetISO
            )
            return false
        } catch {
            print("⚠️ [RealtimeVM] Preflight failed: \(error.localizedDescription) — failing open")
            return true
        }
    }

    /// Detect whether a server error message represents a quota / subscription
    /// refusal (vs a generic network error). Matches localized Uzbek + English
    /// keywords from the backend's error responses. If true, the View routes
    /// to the paywall instead of showing a transient error alert.
    private static func looksLikeQuotaRefusal(_ message: String) -> Bool {
        let m = message.lowercased()
        // Uzbek: "limit", "limiti", "rejangizni yangilang", "obuna", "daqiqa", "ovozli"
        // English: "limit", "quota", "upgrade", "voice"
        let needles = [
            "limit",        // matches "limiti", "limitiga", "limit exceeded"
            "quota",
            "rejangiz",     // matches "rejangizni"
            "obuna",        // matches "obunangizda"
            "ovozli rejim", // "voice mode not in plan"
            "upgrade",
            "voice mode",
        ]
        return needles.contains { m.contains($0) }
    }

    private static func localizedBlockMessage(
        for reason: String,
        used: Double,
        limit: Int,
        resetISO: String?
    ) -> String {
        let resetSuffix: String = {
            guard let resetISO else { return "" }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = iso.date(from: resetISO) ?? ISO8601DateFormatter().date(from: resetISO)
            guard let date else { return "" }
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            fmt.locale = Locale(identifier: "uz")
            return " Limit \(fmt.string(from: date)) kuni yangilanadi."
        }()

        switch reason {
        case "minutes_exceeded":
            return "Oylik ovozli daqiqalar limiti tugadi (\(Int(used))/\(limit) daq).\(resetSuffix) Rejangizni yangilang yoki keyinroq qaytib keling."
        case "voice_disabled":
            return "Ovozli rejim ushbu obunada mavjud emas. Premium rejaga o'ting."
        default:
            return "Ovozli rejim hozircha mavjud emas."
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

    /// Play a preview clip (MP3) returned by `GET /realtime/voice-preview`.
    /// Routes through `RealtimeAudioManager.playAudio(data:)` which already
    /// handles MP3 natively.
    func playPreview(data: Data) {
        audioManager.playAudio(data: data)
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
