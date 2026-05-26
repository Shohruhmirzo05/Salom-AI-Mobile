//
//  OpenAIRealtimeManager.swift
//  Salom-Ai-iOS
//
//  Connects to the Salom-AI backend's OpenAI Realtime proxy (`/realtime/ws`)
//  and speaks OpenAI's Realtime wire protocol natively. The backend handles
//  the OpenAI session.update, auth, subscription gating, and history
//  persistence; this client only ferries audio and surfaces transcripts/state
//  to the rest of the iOS app.
//
//  Design:
//  - Implements `RealtimeVoiceProviding` so RealtimeVoiceViewModel can swap
//    it in for `RealtimeWebSocketManager` with no other changes.
//  - Mic input: receives 16 kHz PCM16 raw bytes from RealtimeAudioManager
//    (via ViewModel), base64-encodes, wraps in `input_audio_buffer.append`.
//  - Audio output: parses `response.audio.delta` events, base64-decodes,
//    streams 24 kHz PCM16 to an internal AVAudioEngine + AVAudioPlayerNode
//    (low-latency, chunked, no file-based playback).
//  - Server VAD on the OpenAI side handles turn-taking. Barge-in is wired
//    via the existing audio manager's onSpeechDetected callback, which
//    sends `response.cancel` + `output_audio_buffer.clear`.
//

import Foundation
import Combine
import AVFoundation
import SwiftUI

// MARK: - Streaming PCM Player

/// Plays a stream of raw PCM16 chunks at a fixed sample rate (24 kHz for
/// OpenAI Realtime) using AVAudioEngine + AVAudioPlayerNode. Chunks are
/// scheduled as soon as they arrive — no buffering/file decoding lag.
@MainActor
final class OpenAIRealtimePCMPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let outputFormat: AVAudioFormat
    private let sampleRate: Double = 24000  // OpenAI Realtime audio output rate
    private var isEngineRunning = false
    private(set) var isPlaying = false

    /// Audio level (0…1, RMS) for visualizer.
    private(set) var outputLevel: Float = 0.0

    /// Optional callback invoked when the player drains (all scheduled chunks
    /// have finished). Useful to flip back to .listening.
    var onPlaybackFinished: (() -> Void)?

    /// Optional callback for output audio level updates (visualizer feed).
    var onLevel: ((Float) -> Void)?

    private var pendingChunkCount: Int = 0

    init() {
        // 24 kHz mono Float32 — AVAudioPlayerNode requires a float format.
        // We convert incoming PCM16 → Float32 in `enqueue(pcm16:)`.
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ) else {
            fatalError("OpenAIRealtimePCMPlayer: failed to create output format")
        }
        outputFormat = format

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: outputFormat)
    }

    /// Start the audio engine + player node if not already running.
    func start() {
        guard !isEngineRunning else { return }
        do {
            try engine.start()
            playerNode.play()
            isEngineRunning = true
            print("✅ [PCMPlayer] Engine started @ \(Int(sampleRate)) Hz")
        } catch {
            print("❌ [PCMPlayer] Failed to start engine: \(error.localizedDescription)")
        }
    }

    /// Stop playback immediately and discard any pending scheduled chunks.
    /// Used for barge-in and end-of-call cleanup.
    func stop() {
        playerNode.stop()
        engine.stop()
        isEngineRunning = false
        isPlaying = false
        pendingChunkCount = 0
        outputLevel = 0.0
        onLevel?(0.0)
        print("🛑 [PCMPlayer] Stopped + buffers cleared")
    }

    /// Cancel any unplayed audio without tearing the engine down (so the
    /// next chunk can start playing instantly). For mid-response barge-in.
    func flush() {
        playerNode.stop()
        playerNode.reset()
        pendingChunkCount = 0
        isPlaying = false
        outputLevel = 0.0
        onLevel?(0.0)
        // Re-arm the player so the next scheduled buffer starts immediately.
        if isEngineRunning {
            playerNode.play()
        }
        print("🧹 [PCMPlayer] Flushed mid-response")
    }

    /// Enqueue a raw PCM16 little-endian chunk for playback.
    func enqueue(pcm16: Data) {
        start() // lazy-start on first chunk
        guard !pcm16.isEmpty else { return }
        guard let buffer = makeFloatBuffer(from: pcm16) else { return }

        pendingChunkCount += 1
        isPlaying = true

        // Compute RMS for visualizer.
        let level = rms(of: buffer)
        outputLevel = level
        onLevel?(level)

        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.pendingChunkCount = max(0, self.pendingChunkCount - 1)
                if self.pendingChunkCount == 0 {
                    self.isPlaying = false
                    self.outputLevel = 0.0
                    self.onLevel?(0.0)
                    self.onPlaybackFinished?()
                }
            }
        }
    }

    // MARK: - Internals

    private func makeFloatBuffer(from pcm16: Data) -> AVAudioPCMBuffer? {
        let sampleCount = pcm16.count / 2
        guard sampleCount > 0,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: AVAudioFrameCount(sampleCount)
              ) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        guard let channel = buffer.floatChannelData?.pointee else { return nil }

        pcm16.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let ints = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                channel[i] = Float(ints[i]) / Float(Int16.max)
            }
        }
        return buffer
    }

    private func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let ch = buffer.floatChannelData?.pointee else { return 0 }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<n {
            let s = ch[i]
            sum += s * s
        }
        return sqrt(sum / Float(n))
    }
}

// MARK: - OpenAI Realtime Manager

@MainActor
final class OpenAIRealtimeManager: NSObject, ObservableObject {
    // MARK: - Published state (mirrors the Yandex provider's surface)
    @Published var connectionState: RealtimeWebSocketState = .disconnected
    @Published var voiceState: RealtimeVoiceState = .idle
    @Published var messages: [RealtimeMessage] = []
    @Published var currentTranscription: String = ""
    @Published var currentAIResponse: String = ""
    /// Language is sourced from the global app preference (the same one the
    /// chat header writes via `AppStorageKeys.preferredLanguageCode`).
    /// Values are short ISO codes: "uz", "uz-Cyrl", "ru", "en".
    /// Voice view + chat header read/write the same key, so they stay in sync.
    @Published var currentLanguage: String = {
        UserDefaults.standard.string(forKey: AppStorageKeys.preferredLanguageCode) ?? "uz"
    }()

    /// RMS of the audio currently being played back by the assistant.
    /// Mirrors `audioManager.streamingPlayerLevel` for the visualizer.
    @Published var outputAudioLevel: Float = 0.0

    var onAudioReceived: ((Data) -> Void)?  // never invoked — audio plays through audioManager

    // MARK: - Networking
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let baseURL = "wss://api.salom-ai.uz/realtime/ws"
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    // MARK: - Audio output
    /// Owned by the ViewModel; we share the same AVAudioEngine so VPIO has
    /// both the mic input AND speaker output on one engine. Set by the
    /// ViewModel right after init via `attach(audioManager:)`.
    weak var audioManager: RealtimeAudioManager?

    /// Track whether the assistant is currently producing audio so we can
    /// detect mid-response barge-in (user starts speaking → cancel).
    private var assistantIsSpeaking = false
    /// Timestamp of when the current assistant turn started outputting audio.
    /// With VPIO enabled (now that engines are consolidated), AEC converges
    /// in ~200ms. The gate is reduced from 1200 → 300 ms so genuine barge-in
    /// works again while still suppressing the loudest startup transient.
    private var assistantSpeakingStartedAt: Date?
    private let micGateAfterAssistantStartMs: Double = 300

    // MARK: - Init
    /// ViewModel calls this once after constructing both objects so the
    /// manager can route audio through the SAME AVAudioEngine as the mic
    /// (required for iOS VPIO / proper AEC).
    func attach(audioManager: RealtimeAudioManager) {
        self.audioManager = audioManager
        // Wire drain callback: when the streaming player finishes its last
        // scheduled chunk, flip voice state back to .listening.
        audioManager.onStreamingDrained = { [weak self] in
            guard let self else { return }
            self.assistantIsSpeaking = false
            self.assistantSpeakingStartedAt = nil
            if self.voiceState == .speaking {
                self.voiceState = .listening
            }
        }
    }

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 600
        urlSession = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)

        // Drain + level callbacks are set in `attach(audioManager:)` once
        // the ViewModel injects the shared audio manager.
    }

    // MARK: - Connect / disconnect

    func connect(token: String) async {
        reconnectTask?.cancel()
        reconnectTask = nil

        guard connectionState != .connected && connectionState != .connecting else {
            print("🔌 [OpenAI-RT] Already connected/connecting")
            return
        }

        // Refresh access token before connecting.
        do {
            try await APIClient.shared.refreshAccessToken()
        } catch {
            print("⚠️ [OpenAI-RT] Token refresh failed; using current token: \(error.localizedDescription)")
        }

        await fetchUserSettings()

        guard let freshToken = TokenStore.shared.accessToken else {
            print("❌ [OpenAI-RT] No access token")
            connectionState = .error("No access token")
            scheduleReconnect()
            return
        }

        guard var comps = URLComponents(string: baseURL) else {
            connectionState = .error("Invalid URL")
            return
        }
        // Map our two-letter language code on the connect URL so the backend
        // picks the right system prompt without an extra round trip.
        let langShort = String(currentLanguage.prefix(2)).lowercased()
        comps.queryItems = [
            URLQueryItem(name: "token", value: freshToken),
            URLQueryItem(name: "lang", value: langShort),
        ]
        guard let url = comps.url else {
            connectionState = .error("Invalid URL")
            return
        }

        print("🔌 [OpenAI-RT] Connecting to \(url.absoluteString)")
        connectionState = .connecting

        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()

        receiveLoop()
        startPing()
    }

    func disconnect() {
        print("🔌 [OpenAI-RT] Disconnecting (user-initiated)")
        pingTask?.cancel(); pingTask = nil
        reconnectTask?.cancel(); reconnectTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        audioManager?.flushStreaming()
        connectionState = .disconnected
        voiceState = .idle
        assistantIsSpeaking = false
        assistantSpeakingStartedAt = nil
        reconnectAttempts = 0
    }

    // MARK: - Send (mic → OpenAI)

    /// Forward a raw 24 kHz PCM16 chunk from the mic, wrapped in OpenAI's
    /// `input_audio_buffer.append` JSON envelope (base64-encoded audio).
    ///
    /// Gating: during the first `micGateAfterAssistantStartMs` of any assistant
    /// turn, we DROP mic chunks instead of forwarding them. iOS's session-level
    /// AEC needs ~half a second of speaker output to converge on a reference;
    /// before that, residual speaker→mic leak is loud enough to trigger
    /// OpenAI's server VAD and self-cancel the assistant. After the gate, the
    /// stream resumes so genuine user barge-in still works.
    func sendAudioChunk(_ data: Data) {
        guard connectionState == .connected else { return }

        if assistantIsSpeaking, let started = assistantSpeakingStartedAt {
            let elapsedMs = Date().timeIntervalSince(started) * 1000
            if elapsedMs < micGateAfterAssistantStartMs {
                // Drop — speaker leak is still louder than AEC can suppress.
                return
            }
        }

        let b64 = data.base64EncodedString()
        sendJSON(["type": "input_audio_buffer.append", "audio": b64])
    }

    /// With server_vad on the OpenAI side, explicit utterance commits are
    /// not required — the server commits + creates a response automatically.
    /// We keep this as a no-op so the protocol surface matches Yandex.
    func sendEndUtterance() {
        // No-op for OpenAI provider (server_vad handles this).
    }

    /// User started talking. If the assistant is currently speaking, cancel
    /// its response and flush playback — that's the ChatGPT-app barge-in feel.
    func sendSpeechStarted() {
        if assistantIsSpeaking {
            cancelAssistantResponse()
        }
    }

    /// Hard interruption (e.g. user tapped the stop button). Same as
    /// sendSpeechStarted but always fires regardless of assistant state.
    func sendInterruption() {
        cancelAssistantResponse()
    }

    private func cancelAssistantResponse() {
        guard connectionState == .connected else { return }
        print("✋ [OpenAI-RT] Cancelling assistant response (barge-in)")
        // Tell OpenAI to stop generating + drop any audio still on the wire.
        sendJSON(["type": "response.cancel"])
        sendJSON(["type": "output_audio_buffer.clear"])
        // Drop any buffered audio on our side via the shared engine.
        audioManager?.flushStreaming()
        assistantIsSpeaking = false
        assistantSpeakingStartedAt = nil
        voiceState = .listening
    }

    /// Mid-call language switch — the backend listens for `salom.set_language`
    /// and rebuilds the system prompt without dropping the WebSocket. Also
    /// writes through to AppStorage so the chat header reflects the change.
    func changeLanguage(_ language: String, voice: String?, role: String?) {
        currentLanguage = language
        UserDefaults.standard.set(language, forKey: AppStorageKeys.preferredLanguageCode)
        guard connectionState == .connected else { return }
        let short = String(language.prefix(2)).lowercased()
        sendJSON(["type": "salom.set_language", "language": short])
    }

    func sendConfigUpdate(language: String, voice: String, role: String?) {
        // OpenAI Realtime doesn't expose mid-stream voice swaps cheaply
        // (would require a full session.update via the proxy). For now we
        // honor the language change; voice/role come from server settings.
        changeLanguage(language, voice: voice, role: role)
    }

    /// Clear local conversation transcript view + flush playback. Does not
    /// touch the OpenAI conversation (the next utterance still has history).
    func reset() {
        messages.removeAll()
        currentTranscription = ""
        currentAIResponse = ""
        voiceState = .idle
        audioManager?.flushStreaming()
        assistantIsSpeaking = false
    }

    // MARK: - Settings fetch (mirrors Yandex provider behavior)

    /// AppStorage is the source of truth for language now — no backend fetch.
    /// We just re-read what the user picked (in chat header or voice settings)
    /// so the WS connect uses the freshest value.
    func fetchUserSettings() async {
        let stored = UserDefaults.standard.string(forKey: AppStorageKeys.preferredLanguageCode) ?? "uz"
        await MainActor.run { self.currentLanguage = stored }
        print("🌐 [OpenAI-RT] Using language from AppStorage: \(stored)")
    }

    // MARK: - JSON send helper

    private func sendJSON(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else {
            return
        }
        webSocket?.send(.string(str)) { error in
            if let error = error {
                print("❌ [OpenAI-RT] send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Receive loop

    private func receiveLoop() {
        let activeTask = webSocket
        webSocket?.receive { [weak self] result in
            // The closure fires on URLSession's delegate queue (background).
            // Hop to MainActor before reading any state on this @MainActor class.
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Guard against stale callbacks after a reconnect swapped the socket.
                guard activeTask === self.webSocket else { return }

                switch result {
                case .success(let message):
                    self.handle(message: message)
                    self.receiveLoop()
                case .failure(let error):
                    let nsErr = error as NSError
                    print("❌ [OpenAI-RT] Receive failed: \(error.localizedDescription) code=\(nsErr.code)")
                    if nsErr.code == NSURLErrorCancelled { return }
                    self.handleNetworkError()
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            // The OpenAI proxy currently passes through any binary frames
            // (which OpenAI Realtime does not emit by default — audio comes
            // base64-encoded inside JSON). Treat any binary as raw PCM16 just
            // in case a future server config flips to binary frames.
            audioManager?.enqueueStreamingPCM16(data)
        case .string(let text):
            guard let bytes = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  let type = json["type"] as? String else {
                return
            }
            route(event: type, payload: json)
        @unknown default:
            break
        }
    }

    private func route(event: String, payload: [String: Any]) {
        switch event {
        // ─── OpenAI Realtime events ────────────────────────────────────
        case "session.created", "session.updated":
            print("🤝 [OpenAI-RT] \(event)")
            if connectionState != .connected {
                connectionState = .connected
                reconnectAttempts = 0
            }
            // Kick the ViewModel into .listening so it starts the mic.
            // Server VAD will then drive transitions from there.
            if voiceState == .idle {
                voiceState = .listening
            }

        case "input_audio_buffer.speech_started":
            // Server-VAD says user started talking. If assistant is mid-reply,
            // OpenAI will already auto-interrupt (interrupt_response: true)
            // but we still flush our local audio so playback stops instantly.
            if assistantIsSpeaking {
                audioManager?.flushStreaming()
                assistantIsSpeaking = false
            }
            voiceState = .listening

        case "input_audio_buffer.speech_stopped":
            voiceState = .transcribing

        case "conversation.item.input_audio_transcription.completed":
            if let transcript = payload["transcript"] as? String, !transcript.isEmpty {
                currentTranscription = transcript
                messages.append(RealtimeMessage(text: transcript, isUser: true, timestamp: Date()))
                print("📝 [OpenAI-RT] User said: \(transcript)")
            }

        case "response.created":
            voiceState = .thinking
            assistantIsSpeaking = true

        case "response.output_item.added", "response.content_part.added":
            voiceState = .speaking

        // GA event names: response.output_audio.*  (Beta names: response.audio.*).
        // Handle both so a deploy mid-rollout doesn't break clients.
        case "response.output_audio.delta", "response.audio.delta":
            if let b64 = payload["delta"] as? String,
               let pcm = Data(base64Encoded: b64) {
                voiceState = .speaking
                if !assistantIsSpeaking {
                    // First chunk of this turn — start the mic-uplink gate.
                    assistantSpeakingStartedAt = Date()
                }
                assistantIsSpeaking = true
                // Schedule on the shared engine's player node so VPIO uses
                // this exact audio as the AEC reference.
                audioManager?.enqueueStreamingPCM16(pcm)
                outputAudioLevel = audioManager?.streamingPlayerLevel ?? 0
            }

        case "response.output_audio_transcript.delta", "response.audio_transcript.delta":
            if let delta = payload["delta"] as? String {
                currentAIResponse += delta
            }

        case "response.output_audio_transcript.done", "response.audio_transcript.done":
            if let transcript = payload["transcript"] as? String, !transcript.isEmpty {
                messages.append(RealtimeMessage(text: transcript, isUser: false, timestamp: Date()))
                currentAIResponse = ""
                print("🤖 [OpenAI-RT] Assistant said: \(transcript)")
            }

        case "response.done":
            // assistantIsSpeaking flips false when the player drains, not now,
            // so barge-in works during the final-buffer tail.
            print("✅ [OpenAI-RT] response.done")

        case "error":
            let err = payload["error"] as? [String: Any]
            let code = (err?["code"] as? String) ?? ""
            let msg = (err?["message"] as? String) ?? "Unknown error"
            print("❌ [OpenAI-RT] Server error: code=\(code) msg=\(msg)")
            // Surface terminal errors (subscription / quota) so the UI shows
            // an alert and we stop trying to reconnect.
            if code == "VOICE_DENIED" || code == "LIMIT_EXCEEDED" {
                reconnectAttempts = maxReconnectAttempts  // suppress auto-reconnect
                connectionState = .error(msg)
            }

        // ─── Salom proxy events ────────────────────────────────────────
        case "salom.language_changed":
            if let lang = payload["language"] as? String {
                currentLanguage = lang
            }

        default:
            // Quiet noise: response.text.delta, response.output_audio.done, etc.
            // Uncomment to debug:
            // print("ℹ️ [OpenAI-RT] event: \(event)")
            break
        }
    }

    // MARK: - Reconnect

    private func startPing() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15s
                guard let self, !Task.isCancelled else { return }
                self.webSocket?.sendPing { error in
                    if let error = error {
                        print("⚠️ [OpenAI-RT] Ping failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func handleNetworkError() {
        connectionState = .error("Network error")
        pingTask?.cancel(); pingTask = nil
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("❌ [OpenAI-RT] Max reconnect attempts reached")
            return
        }
        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        print("🔄 [OpenAI-RT] Reconnect in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled,
                  let token = TokenStore.shared.accessToken else { return }
            await self.connect(token: token)
        }
    }
}

// MARK: - RealtimeVoiceProviding conformance

extension OpenAIRealtimeManager: RealtimeVoiceProviding {
    var connectionStatePublisher: Published<RealtimeWebSocketState>.Publisher { $connectionState }
    var voiceStatePublisher: Published<RealtimeVoiceState>.Publisher { $voiceState }
    var messagesPublisher: Published<[RealtimeMessage]>.Publisher { $messages }
}

// MARK: - URLSessionWebSocketDelegate

extension OpenAIRealtimeManager: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [OpenAI-RT] Transport opened")
        Task { @MainActor [weak self] in
            self?.connectionState = .connecting  // wait for session.created to flip to .connected
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        print("🔌 [OpenAI-RT] Closed: code=\(closeCode.rawValue) reason=\(reasonStr)")
        let code = closeCode.rawValue
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pingTask?.cancel(); self.pingTask = nil
            self.connectionState = .disconnected
            self.voiceState = .idle
            self.audioManager?.flushStreaming()
            // Auto-reconnect for unexpected closes only. Excluded:
            //   1000 normal, 1001 going away (user disconnect),
            //   1008 policy violation (auth),
            //   4xxx application-defined refusals (quota, rate-limit, voice denied).
            let isAppRefusal = code >= 4000 && code < 5000
            if code != 1000 && code != 1001 && code != 1008 && !isAppRefusal {
                self.scheduleReconnect()
            } else if isAppRefusal {
                // Lock out reconnect attempts so the receive-failure callback
                // that fires moments later can't sneak past this guard via
                // handleNetworkError → scheduleReconnect. (Hammering a 4xxx
                // refusal just refreshes the same rate-limit / quota error.)
                self.reconnectAttempts = self.maxReconnectAttempts
                let msg = reasonStr.isEmpty ? "Connection refused (\(code))" : reasonStr
                self.connectionState = .error(msg)
            }
        }
    }
}
