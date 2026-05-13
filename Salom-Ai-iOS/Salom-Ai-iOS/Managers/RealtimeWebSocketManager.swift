//
//  RealtimeWebSocketManager.swift
//  Salom-Ai-iOS
//
//  Real-time WebSocket connection manager for voice conversations
//

import Foundation
import Combine
import SwiftUI

enum RealtimeWebSocketState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

enum RealtimeVoiceState: String {
    case idle
    case listening
    case transcribing
    case thinking
    case speaking
}

struct RealtimeMessage {
    let text: String
    let isUser: Bool
    let timestamp: Date
}

class RealtimeWebSocketManager: NSObject, ObservableObject {
    @Published var connectionState: RealtimeWebSocketState = .disconnected
    @Published var voiceState: RealtimeVoiceState = .idle
    @Published var messages: [RealtimeMessage] = []
    @Published var currentTranscription: String = ""
    @Published var currentAIResponse: String = ""
    @Published var currentLanguage: String = "uz-UZ"
    
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let baseURL = "wss://api.salom-ai.uz/ws/voice/yandex/realtime"
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var lastPingTime: Date?
    
    var onAudioReceived: ((Data) -> Void)?
    
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func connect(token: String) async {
        // Cancel any pending reconnect
        reconnectTask?.cancel()
        reconnectTask = nil
        
        guard connectionState != .connected && connectionState != .connecting else {
            print("🔌 [RealtimeWS] Already connected or connecting")
            return
        }
        
        // Refresh token before connecting to ensure it's valid
        print("🔄 [RealtimeWS] Refreshing token before connection...")
        do {
            try await APIClient.shared.refreshAccessToken()
            print("✅ [RealtimeWS] Token refreshed successfully")
        } catch {
            print("⚠️ [RealtimeWS] Token refresh failed, using existing token: \(error.localizedDescription)")
        }
        
        // Fetch user settings to get main_language
        await fetchUserSettings()
        
        // Get the latest token after refresh
        guard let freshToken = TokenStore.shared.accessToken else {
            print("❌ [RealtimeWS] No access token available")
            await MainActor.run {
                connectionState = .error("No access token")
            }
            scheduleReconnect()
            return
        }
        
        guard var urlComponents = URLComponents(string: baseURL) else {
            print("❌ [RealtimeWS] Invalid base URL")
            await MainActor.run {
                connectionState = .error("Invalid URL")
            }
            return
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "token", value: freshToken)]
        
        guard let url = urlComponents.url else {
            print("❌ [RealtimeWS] Failed to construct URL")
            await MainActor.run {
                connectionState = .error("Invalid URL")
            }
            return
        }
        
        print("🔌 [RealtimeWS] Connecting to \(url.absoluteString)")
        await MainActor.run {
            connectionState = .connecting
        }
        
        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()
        
        receiveMessage()
        startPingTask()
    }
    
    private func startPingTask() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            // Use a short interval (15s) for both protocol-level pings (to keep NAT/proxies alive)
            // and app-level pings (so the backend knows we're still here).
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                guard let self, !Task.isCancelled else { return }

                // Protocol-level ping — critical for cellular NAT + proxies that drop idle WS at 30-60s.
                // Do this regardless of app-level connectionState so we keep the transport alive
                // even before the server's "connected" JSON event arrives.
                self.webSocket?.sendPing { error in
                    if let error = error {
                        print("⚠️ [RealtimeWS] Protocol ping failed: \(error.localizedDescription)")
                    }
                }

                // App-level ping only after we're fully connected (server expects authed session).
                if self.connectionState == .connected {
                    let pingMessage: [String: Any] = ["type": "ping", "timestamp": Date().timeIntervalSince1970]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: pingMessage),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        self.webSocket?.send(.string(jsonString)) { [weak self] error in
                            if let error = error {
                                print("⚠️ [RealtimeWS] App ping failed: \(error.localizedDescription)")
                            } else {
                                self?.lastPingTime = Date()
                            }
                        }
                    }
                }
                // continue — never break out of the loop
            }
        }
    }
    
    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("❌ [RealtimeWS] Max reconnect attempts reached")
            return
        }
        
        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Exponential backoff, max 30s
        
        print("🔄 [RealtimeWS] Scheduling reconnect in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            
            guard let token = TokenStore.shared.accessToken else { return }
            await connect(token: token)
        }
    }
    
    func disconnect() {
        print("🔌 [RealtimeWS] Disconnecting (user-initiated)")
        pingTask?.cancel()
        pingTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        // .goingAway = 1001 — our didCloseWith handler treats this as user-initiated and skips auto-reconnect.
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.voiceState = .idle
        }
        reconnectAttempts = 0
    }
    
    func sendAudioChunk(_ data: Data) {
        guard connectionState == .connected else {
            print("⚠️ [RealtimeWS] Not connected, cannot send audio")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocket?.send(message) { [weak self] error in
            if let error = error {
                print("❌ [RealtimeWS] Failed to send audio: \(error.localizedDescription)")
                self?.handleError(error)
            }
        }
    }
    
    func sendEndUtterance() {
        let message = ["type": "end_utterance"]
        sendJSON(message, debugMessage: "end_utterance")
    }
    
    func sendSpeechStarted() {
        let message = ["type": "speech_started"]
        sendJSON(message, debugMessage: "speech_started")
    }
    
    func sendInterruption() {
        let message = ["type": "interrupt"]
        sendJSON(message, debugMessage: "interrupt")
    }

    /// Switch language mid-call without dropping the WebSocket.
    /// Sends a config_update so the backend rebuilds the system prompt with the new locale.
    func changeLanguage(_ language: String, voice: String? = nil, role: String? = nil) {
        DispatchQueue.main.async {
            self.currentLanguage = language
        }
        guard connectionState == .connected else {
            print("ℹ️ [RealtimeWS] changeLanguage queued — not connected yet")
            return
        }
        var data: [String: Any] = ["language": language]
        if let v = voice { data["voice"] = v }
        if let r = role { data["role"] = r }
        sendJSON(["type": "config_update", "data": data], debugMessage: "config_update(lang)")
    }
    
    // MARK: - Settings Sync
    func fetchUserSettings() async {
        guard let token = TokenStore.shared.accessToken else {
            print("⚠️ [RealtimeWS] No token for settings fetch")
            return
        }
        
        do {
            let url = URL(string: "https://api.salom-ai.uz/settings")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("⚠️ [RealtimeWS] Failed to fetch settings")
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let preferences = json["preferences"] as? [String: Any],
               let mainLanguage = preferences["main_language"] as? String {
                await MainActor.run {
                    print("🌐 [RealtimeWS] Updated language from backend: \(mainLanguage)")
                    self.currentLanguage = mainLanguage
                }
            } else {
                print("⚠️ [RealtimeWS] No main_language in settings, using default")
            }
        } catch {
            print("❌ [RealtimeWS] Error fetching settings: \(error.localizedDescription)")
        }
    }
    
    // Config update is now handled via REST API for preview/persistence
    // But we might want to send it if we are connected to update the ACTIVE session
    // However, since we disconnect on settings open, the next connect will load from DB.
    // So we don't strictly need this anymore, but keeping it for potential live updates if design changes.
    func sendConfigUpdate(language: String, voice: String, role: String?) {
        DispatchQueue.main.async {
            self.currentLanguage = language
        }
        
        // Only send if connected (which we likely aren't during settings)
        guard connectionState == .connected else { return }
        
        var data: [String: Any] = [
            "language": language,
            "voice": voice
        ]
        if let role = role {
            data["role"] = role
        }
        
        let message: [String: Any] = [
            "type": "config_update",
            "data": data
        ]
        sendJSON(message, debugMessage: "config_update")
    }
    
    private func sendJSON(_ jsonObject: [String: Any], debugMessage: String) {
        guard connectionState == .connected else { return }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject) else {
            print("❌ [RealtimeWS] Failed to serialize \(debugMessage) JSON")
            return
        }
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [RealtimeWS] Failed to convert \(debugMessage) JSON data to string")
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(wsMessage) { error in
            if let error = error {
                print("❌ [RealtimeWS] Failed to send \(debugMessage): \(error.localizedDescription)")
            } else {
                print("📤 [RealtimeWS] \(debugMessage) sent")
            }
        }
    }
    
    func reset() {
        guard connectionState == .connected else { return }

        // Use sendJSON helper which correctly sends as .string (not .data)
        // Backend expects JSON control messages as text frames, not binary
        let resetMessage = ["type": "reset"]
        sendJSON(resetMessage, debugMessage: "reset")

        DispatchQueue.main.async {
            self.messages.removeAll()
            self.currentTranscription = ""
            self.currentAIResponse = ""
            self.voiceState = .idle
        }
    }
    
    private func receiveMessage() {
        // Capture the task ID so a stale closure from an older socket cannot resurrect
        // the receive loop after we've reconnected with a new task.
        let activeTask = webSocket
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            // If our underlying task changed (reconnect happened), stop this receive chain.
            guard activeTask === self.webSocket else {
                print("⚠️ [RealtimeWS] Stale receive callback ignored")
                return
            }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage() // Continue receiving

            case .failure(let error):
                let nsErr = error as NSError
                print("❌ [RealtimeWS] Receive error: \(error.localizedDescription) (code=\(nsErr.code))")
                // Cancelled (user disconnect / new connect) — do not reconnect.
                if nsErr.code == NSURLErrorCancelled {
                    return
                }
                self.handleError(error)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            // Binary data = audio response
            print("🎵 [RealtimeWS] Received audio: \(data.count) bytes")
            DispatchQueue.main.async {
                self.onAudioReceived?(data)
            }
            
        case .string(let text):
            // JSON event
            guard let jsonData = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = json["type"] as? String else {
                print("⚠️ [RealtimeWS] Failed to parse JSON message")
                return
            }
            
            print("📨 [RealtimeWS] Event: \(type)")
            handleEvent(type: type, data: json["data"] as? [String: Any])
            
        @unknown default:
            print("⚠️ [RealtimeWS] Unknown message type")
        }
    }
    
    private func handleEvent(type: String, data: [String: Any]?) {
        DispatchQueue.main.async {
            switch type {
            case "connected":
                print("✅ [RealtimeWS] Connected")
                self.connectionState = .connected
                self.reconnectAttempts = 0
                
            case "state":
                if let stateStr = data?["state"] as? String,
                   let state = RealtimeVoiceState(rawValue: stateStr) {
                    print("🔄 [RealtimeWS] State: \(stateStr)")
                    self.voiceState = state
                }
                
            case "transcription":
                if let text = data?["text"] as? String {
                    print("📝 [RealtimeWS] Transcription: \(text)")
                    self.currentTranscription = text
                    let message = RealtimeMessage(text: text, isUser: true, timestamp: Date())
                    self.messages.append(message)
                }
                
            case "ai_response":
                if let text = data?["text"] as? String {
                    print("🤖 [RealtimeWS] AI Response: \(text)")
                    self.currentAIResponse = text
                    let message = RealtimeMessage(text: text, isUser: false, timestamp: Date())
                    self.messages.append(message)
                }
                
            case "error":
                if let errorMsg = data?["message"] as? String {
                    print("❌ [RealtimeWS] Error: \(errorMsg)")
                    // Don't disconnect on STT errors - just log and continue
                    // The backend will send a state update to return to listening
                    // Only show error in UI, don't change connection state
                }
                
            case "config_update":
                if let language = data?["language"] as? String {
                    print("⚙️ [RealtimeWS] Config received: \(language)")
                    self.currentLanguage = language
                }
                
            default:
                print("⚠️ [RealtimeWS] Unknown event type: \(type)")
            }
        }
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.connectionState = .error(error.localizedDescription)
            self.pingTask?.cancel()
            self.pingTask = nil
            // Use the shared reconnect logic with exponential backoff
            self.scheduleReconnect()
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension RealtimeWebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [RealtimeWS] WebSocket transport opened")
        // Transport is up — reset the backoff counter so we don't burn attempts
        // on silent auth failures that never produce a server "connected" event.
        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.reconnectAttempts = 0
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        print("🔌 [RealtimeWS] WebSocket closed: code=\(closeCode.rawValue) reason=\(reasonStr)")
        // Always cancel the ping task; a stale one would race with the next connect.
        pingTask?.cancel()
        pingTask = nil

        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.voiceState = .idle
        }

        // Auto-reconnect for unexpected closes (not user-initiated and not auth failures).
        // 1000 = normal, 1001 = going away (we set this on disconnect()), 1008 = policy violation (auth).
        let code = closeCode.rawValue
        if code != 1000 && code != 1001 && code != 1008 {
            DispatchQueue.main.async { [weak self] in
                self?.scheduleReconnect()
            }
        }
    }
}
