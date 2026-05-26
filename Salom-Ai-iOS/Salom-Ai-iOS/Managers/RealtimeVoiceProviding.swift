//
//  RealtimeVoiceProviding.swift
//  Salom-Ai-iOS
//
//  Protocol abstraction so the ViewModel can swap between the legacy Yandex
//  pipeline (STT → LLM → TTS over a custom WS protocol) and the OpenAI
//  Realtime API (full-duplex audio over OpenAI's wire protocol) without
//  any behavior changes in the UI layer.
//
//  Provider selection lives in `RealtimeProviderConfig.current` (see below).
//  Default ships as `.openai` to match the ChatGPT-app experience.
//

import Foundation
import Combine

@MainActor
protocol RealtimeVoiceProviding: AnyObject {
    // MARK: - Observed state
    var connectionState: RealtimeWebSocketState { get }
    var voiceState: RealtimeVoiceState { get }
    var messages: [RealtimeMessage] { get }
    var currentTranscription: String { get }
    var currentAIResponse: String { get }
    var currentLanguage: String { get set }

    // Combine publishers (exposed via @Published projectors in concrete classes).
    var connectionStatePublisher: Published<RealtimeWebSocketState>.Publisher { get }
    var voiceStatePublisher: Published<RealtimeVoiceState>.Publisher { get }
    var messagesPublisher: Published<[RealtimeMessage]>.Publisher { get }

    // Optional binary audio sink — only invoked by the Yandex provider, which
    // emits Yandex-TTS MP3 blobs and expects the audio manager to play them.
    // The OpenAI provider plays audio internally (24 kHz PCM16 streamed via
    // AVAudioEngine) and never calls this; safe to leave nil.
    var onAudioReceived: ((Data) -> Void)? { get set }

    // MARK: - Lifecycle
    func connect(token: String) async
    func disconnect()

    // MARK: - Audio + control
    func sendAudioChunk(_ data: Data)
    func sendEndUtterance()
    func sendSpeechStarted()
    func sendInterruption()
    func reset()

    // MARK: - Settings
    func changeLanguage(_ language: String, voice: String?, role: String?)
    func sendConfigUpdate(language: String, voice: String, role: String?)
    func fetchUserSettings() async
}

// MARK: - Feature flag
//
// Switch between providers without touching call sites. Persisted in
// UserDefaults so support/QA can flip from inside the app (Settings →
// Developer) without rebuilding.
//
enum RealtimeProvider: String {
    case yandex
    case openai
}

enum RealtimeProviderConfig {
    private static let defaultsKey = "salom.realtime.provider"

    /// Source of truth. Reads UserDefaults; falls back to `.openai`
    /// (current default — ChatGPT-app quality is the target).
    static var current: RealtimeProvider {
        get {
            if let raw = UserDefaults.standard.string(forKey: defaultsKey),
               let provider = RealtimeProvider(rawValue: raw) {
                return provider
            }
            return .openai
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    /// Factory — call this once in the ViewModel init.
    @MainActor
    static func makeProvider() -> any RealtimeVoiceProviding {
        switch current {
        case .yandex:
            return RealtimeWebSocketManager()
        case .openai:
            return OpenAIRealtimeManager()
        }
    }
}
