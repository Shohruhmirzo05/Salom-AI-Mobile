//
//  APIClient.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 23/01/25.
//

import Foundation
import SwiftUI

final class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    let baseURL: URL
    private let decoder: JSONDecoder = APIClient.makeDecoder()
    
    private init(session: URLSession = .shared) {
        self.session = session
        // Resolve base URL from Info.plist or environment, falling back to production API
        if let baseString = Bundle.main.infoDictionary?["API_BASE_URL"] as? String,
           let url = URL(string: baseString) {
            self.baseURL = url
        } else if let envBase = ProcessInfo.processInfo.environment["API_BASE_URL"],
                  let url = URL(string: envBase) {
            self.baseURL = url
        } else {
            // Default to production server
            self.baseURL = URL(string: "https://api.salom-ai.uz")!
        }
        print("🌐 API Base URL: \(self.baseURL.absoluteString)")
    }
    
    // MARK: - Public
    
    func request<T: Decodable>(_ endpoint: Endpoint, decodeTo: T.Type) async throws -> T {
        let (data, _) = try await dataRequest(endpoint)
        return try decoder.decode(T.self, from: data)
    }
    
    func requestData(_ endpoint: Endpoint) async throws -> Data {
        let (data, _) = try await dataRequest(endpoint)
        return data
    }
    
    func requestWithHeaders(_ endpoint: Endpoint) async throws -> (Data, HTTPURLResponse) {
        return try await dataRequest(endpoint)
    }
    
    // MARK: - Core
    
    private func dataRequest(_ endpoint: Endpoint, allowRetry: Bool = true, retryCount: Int = 0) async throws -> (Data, HTTPURLResponse) {
        let maxRetries = 3
        
        do {
            let request = try buildRequest(for: endpoint)
            debugLogRequest(request, includeBody: !endpoint.isMultipart)
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            debugLogResponse(response: httpResponse, data: data)
            
            if httpResponse.statusCode == 401 {
                if allowRetry, TokenStore.shared.refreshToken != nil {
                    if case .refresh = endpoint {
                        await MainActor.run { SessionManager.shared.logout() }
                        throw APIError.unauthorized
                    }
                    
                    do {
                        try await refreshAccessToken()
                        return try await dataRequest(endpoint, allowRetry: false, retryCount: retryCount)
                    } catch {
                        await MainActor.run { SessionManager.shared.logout() }
                        throw APIError.unauthorized
                    }
                } else {
                    await MainActor.run { SessionManager.shared.logout() }
                    throw APIError.unauthorized
                }
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = try? decoder.decode(StatusMessageResponse.self, from: data).detail
                throw APIError.server(status: httpResponse.statusCode, message: message)
            }
            
            return (data, httpResponse)
        } catch {
            // Retry on network errors (connection lost, timeout, etc.)
            if retryCount < maxRetries,
               let urlError = error as? URLError,
               [.networkConnectionLost, .timedOut, .cannotConnectToHost, .notConnectedToInternet].contains(urlError.code) {
                print("⚠️ Network error (attempt \(retryCount + 1)/\(maxRetries)): \(urlError.localizedDescription). Retrying...")
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 500_000_000)) // Exponential backoff
                return try await dataRequest(endpoint, allowRetry: allowRetry, retryCount: retryCount + 1)
            }
            throw error
        }
    }
    
    private var refreshTask: Task<Void, Error>?

    func refreshAccessToken() async throws {
        // If a refresh is already in progress, wait for it
        if let task = refreshTask {
            return try await task.value
        }
        
        // Create a new refresh task
        let task = Task {
            guard let refreshToken = TokenStore.shared.refreshToken else {
                throw APIError.unauthorized
            }
            let response: TokenPair = try await request(.refresh(refreshToken: refreshToken), decodeTo: TokenPair.self)
            TokenStore.shared.save(accessToken: response.accessToken, refreshToken: response.refreshToken)
        }
        
        self.refreshTask = task
        
        do {
            try await task.value
            self.refreshTask = nil
        } catch {
            self.refreshTask = nil
            throw error
        }
    }

    func chatStream(_ endpoint: Endpoint, allowRetry: Bool = true) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(for: endpoint)
                    let (bytes, response) = try await self.session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIError.invalidResponse)
                        return
                    }
                    
                    if httpResponse.statusCode == 401 {
                        if allowRetry, TokenStore.shared.refreshToken != nil {
                            try await self.refreshAccessToken()
                            let retryStream = self.chatStream(endpoint, allowRetry: false)
                            for try await event in retryStream {
                                continuation.yield(event)
                            }
                            continuation.finish()
                            return
                        } else {
                            await MainActor.run { SessionManager.shared.logout() }
                            continuation.finish(throwing: APIError.unauthorized)
                            return
                        }
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var message = "Stream failed"
                        // Try to read error body if possible, but bytes already consumed? 
                        // For now keep it simple.
                        continuation.finish(throwing: APIError.server(status: httpResponse.statusCode, message: message))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            let trimmed = jsonString.trimmingCharacters(in: .whitespaces)
                            if trimmed == "[DONE]" { continue }
                            if let data = jsonString.data(using: .utf8) {
                                do {
                                    let event = try self.decoder.decode(ChatStreamEvent.self, from: data)
                                    continuation.yield(event)
                                } catch {
                                    print("❌ Failed to decode stream event: \(error)")
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Request Builder
    
    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        let url = try endpoint.url(baseURL: baseURL)
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 60
        
        var headers: [String: String] = [
            "Accept": "application/json"
        ]
        
        if endpoint.isMultipart {
            let boundary = UUID().uuidString
            headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
            request.httpBody = endpoint.multipartBody(boundary: boundary)
        } else if endpoint.method != .get {
            headers["Content-Type"] = "application/json"
            if let body = endpoint.body {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)
            }
        }
        
        if endpoint.requiresAuth, let token = TokenStore.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        request.allHTTPHeaderFields = headers
        return request
    }
    
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            
            // Try fractional seconds first (most common from backend)
            if let date = ISO8601DateFormatter.fractional.date(from: string) {
                return date
            }
            // Fallback to standard ISO8601
            if let date = ISO8601DateFormatter.standard.date(from: string) {
                return date
            }
            // Fallback to a custom formatter for variable fractional seconds if needed
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            if let date = formatter.date(from: string) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(string)")
        }
        return decoder
    }
}

// MARK: - Endpoint

extension APIClient {
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    enum Endpoint {
        // Auth
        case requestOTP(phone: String)
        case verifyOTP(phone: String, code: String)
        case refresh(refreshToken: String)
        case logout(refreshToken: String)
        case oauthVerify(accessToken: String)
        case oauthUser
        case updateProfile(language: String?, displayName: String?)
        case updatePlatform(platform: String)
        
        // Chat
        case chat(conversationId: Int?, text: String, projectId: Int?, model: String?, attachments: [String]?)
        case chatStream(conversationId: Int?, text: String, projectId: Int?, model: String?, attachments: [String]?)
        case generateImage(conversationId: Int?, prompt: String, projectId: Int?)
        case saveChat(conversationId: Int, userText: String, assistantText: String)
        case uploadFile(data: Data, filename: String)
        
        // Perplexity
        case perplexityChat(conversationId: Int?, text: String, model: String?, searchMode: String?)
        case perplexityResearch(query: String, reasoningEffort: String)
        case perplexityUsage
        case getModels
        
        // Voice
        case stt(audio: Data, filename: String)
        case tts(text: String)
        case chatVoice(audio: Data, filename: String, conversationId: Int?)
        case ttsStream(text: String)
        
        // Conversations
        case listConversations(limit: Int, offset: Int)
        case getConversation(id: Int)
        case getConversationMessages(id: Int, limit: Int, offset: Int)
        case deleteConversation(id: Int)
        case searchMessages(query: String, conversationId: Int?)
        
        // Subscription
        case listPlans
        case currentSubscription
        case subscribe(plan: String, provider: String)
        case getUsageStats
        
        // Settings
        case getSettings
        case updateSettings(SettingsPayload)
        
        // Account
        case deleteAccount
        case sendFeedback(content: String)
        
        fileprivate var method: HTTPMethod {
            switch self {
            case .listConversations, .getConversation, .getConversationMessages, .perplexityUsage, .currentSubscription, .getSettings, .getModels, .getUsageStats, .listPlans, .oauthUser:
                return .get
            case .deleteConversation, .deleteAccount:
                return .delete
            case .updateSettings, .updateProfile:
                return .put
            case .updatePlatform:
                return .post
            default:
                return .post
            }
        }
        
        fileprivate var requiresAuth: Bool {
            switch self {
            case .requestOTP, .verifyOTP, .refresh, .oauthVerify:
                return false
            default:
                return true
            }
        }
        
        fileprivate var isMultipart: Bool {
            switch self {
            case .uploadFile, .stt, .chatVoice:
                return true
            default:
                return false
            }
        }
        
        fileprivate func url(baseURL: URL) throws -> URL {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            let basePath = baseURL.path == "/" ? "" : baseURL.path
            components?.path = basePath + path
            if !queryItems.isEmpty {
                components?.queryItems = queryItems
            }
            guard let url = components?.url else {
                throw APIError.invalidURL
            }
            return url
        }
        
        private var path: String {
            switch self {
            case .requestOTP:
                return "/auth/request-otp"
            case .verifyOTP:
                return "/auth/verify-otp"
            case .refresh:
                return "/auth/refresh"
            case .logout:
                return "/auth/logout"
            case .chat:
                return "/chat"
            case .chatStream:
                return "/chat/stream"
            case .generateImage:
                return "/chat/generate-image"
            case .uploadFile:
                return "/files/upload"
            case .stt:
                return "/voice/stt"
            case .tts:
                return "/voice/tts"
            case .chatVoice:
                return "/voice/chat"
            case .ttsStream:
                return "/voice/tts-stream"
            case .saveChat:
                return "/chat/save"
            case .oauthVerify:
                return "/auth/oauth/verify"
            case .oauthUser, .updateProfile:
                return "/auth/me"
            case .updatePlatform:
                return "/auth/platform"
            case .perplexityChat:
                return "/perplexity/chat"
            case .perplexityResearch:
                return "/perplexity/research"
            case .perplexityUsage:
                return "/perplexity/usage"
            case .getModels:
                return "/chat/models"
            case .listConversations:
                return "/conversations"
            case .getConversation(let id):
                return "/conversations/\(id)"
            case .getConversationMessages(let id, _, _):
                return "/conversations/\(id)/messages"
            case .deleteConversation(let id):
                return "/conversations/\(id)"
            case .searchMessages:
                return "/conversations/search"
            case .listPlans:
                return "/subscriptions/plans"
            case .currentSubscription:
                return "/subscriptions/current"
            case .subscribe:
                return "/subscriptions/subscribe"
            case .getUsageStats:
                return "/subscriptions/usage"
            case .getSettings, .updateSettings:
                return "/settings"
            case .deleteAccount:
                return "/account"
            case .sendFeedback:
                return "/feedback"
            }
        }
        
        private var queryItems: [URLQueryItem] {
            switch self {
            case .listConversations(let limit, let offset):
                return [
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ]
            case .getConversationMessages(_, let limit, let offset):
                return [
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "skip", value: "\(offset)")
                ]
            default:
                return []
            }
        }
        
        fileprivate var body: [String: Any]? {
            switch self {
            case .requestOTP(let phone):
                return ["phone": phone]
            case .verifyOTP(let phone, let code):
                return ["phone": phone, "code": code]
            case .refresh(let refreshToken),
                 .logout(let refreshToken):
                return ["refresh_token": refreshToken]
            case .oauthVerify(let accessToken):
                return ["access_token": accessToken]
            case .chat(let conversationId, let text, let projectId, let model, let attachments),
                 .chatStream(let conversationId, let text, let projectId, let model, let attachments):
                var body: [String: Any] = ["text": text]
                if let conversationId { body["conversation_id"] = conversationId }
                if let projectId { body["project_id"] = projectId }
                if let model { body["model"] = model }
                if let attachments { body["attachments"] = attachments }
                return body
            case .generateImage(let conversationId, let prompt, let projectId):
                var params: [String: Any] = ["prompt": prompt]
                if let conversationId { params["conversation_id"] = conversationId }
                if let projectId { params["project_id"] = projectId }
                return params
            case .saveChat(let conversationId, let userText, let assistantText):
                return [
                    "conversation_id": conversationId,
                    "user_text": userText,
                    "assistant_text": assistantText
                ]
            case .perplexityChat(let conversationId, let text, let model, let searchMode):
                var body: [String: Any] = ["text": text]
                if let conversationId { body["conversation_id"] = conversationId }
                if let model { body["model"] = model }
                if let searchMode { body["search_mode"] = searchMode }
                return body
            case .perplexityResearch(let query, let reasoningEffort):
                return [
                    "query": query,
                    "reasoning_effort": reasoningEffort
                ]
            case .searchMessages(let query, let conversationId):
                var body: [String: Any] = ["query": query]
                if let conversationId { body["conversation_id"] = conversationId }
                return body
            case .subscribe(let plan, let provider):
                return ["plan": plan, "provider": provider]
            case .updateSettings(let payload):
                var body: [String: Any] = [:]
                if let prompt = payload.systemPrompt { body["system_prompt"] = prompt }
                if let preferences = payload.preferences { body["preferences"] = preferences }
                return body
            case .updateProfile(let language, let displayName):
                var body: [String: Any] = [:]
                if let language { body["language"] = language }
                if let displayName { body["display_name"] = displayName }
                return body
            case .updatePlatform(let platform):
                return ["platform": platform]
            case .sendFeedback(let content):
                return ["content": content, "platform": "ios"]
            case .tts(let text), .ttsStream(let text):
                return ["text": text]
            default:
                return nil
            }
        }
        
        fileprivate func multipartBody(boundary: String) -> Data? {
            guard isMultipart else { return nil }
            
            var body = Data()
            func append(_ string: String) {
                if let data = string.data(using: .utf8) {
                    body.append(data)
                }
            }
            
            switch self {
            case .uploadFile(let data, let filename),
                 .stt(let data, let filename):
                append("--\(boundary)\r\n")
                append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
                append("Content-Type: application/octet-stream\r\n\r\n")
                body.append(data)
                append("\r\n")
            case .chatVoice(let data, let filename, let conversationId):
                append("--\(boundary)\r\n")
                append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
                append("Content-Type: application/octet-stream\r\n\r\n")
                body.append(data)
                append("\r\n")
                
                if let conversationId {
                    append("--\(boundary)\r\n")
                    append("Content-Disposition: form-data; name=\"conversation_id\"\r\n\r\n")
                    append("\(conversationId)\r\n")
                }
            default:
                break
            }
            
            append("--\(boundary)--\r\n")
            return body
        }
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(status: Int, message: String?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .server(let status, let message):
            return message ?? "Request failed with status \(status)"
        }
    }
}

// MARK: - Date helpers

private extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - Debug logging

private extension APIClient {
    func debugLogRequest(_ request: URLRequest, includeBody: Bool) {
        var lines: [String] = []
        let method = request.httpMethod ?? "?"
        let urlString = request.url?.absoluteString ?? "unknown"
        lines.append("➡️ [API] \(method) \(urlString)")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            let masked = headers.map { key, value -> String in
                if key.lowercased() == "authorization" {
                    let suffix = value.suffix(8)
                    return "\(key): Bearer ***\(suffix)"
                }
                return "\(key): \(value)"
            }.joined(separator: ", ")
            lines.append("Headers: \(masked)")
        }
        
        if includeBody, let body = request.httpBody, !body.isEmpty {
            if let pretty = body.prettyJSON(maxLength: 8000) {
                lines.append("Body: \(pretty)")
            } else if body.count < 4000, let utf = String(data: body, encoding: .utf8) {
                lines.append("Body: \(utf)")
            } else {
                lines.append("Body: <\(body.count) bytes>")
            }
        } else if !includeBody, request.httpBody != nil {
            lines.append("Body: <multipart/form-data>")
        }
        
        print(lines.joined(separator: " | "))
    }
    
    func debugLogResponse(response: HTTPURLResponse, data: Data) {
        var lines: [String] = []
        lines.append("⬅️ [API] \(response.statusCode) \(response.url?.absoluteString ?? "")")
        if let pretty = data.prettyJSON(maxLength: 8000) {
            lines.append("Response: \(pretty)")
        } else if data.count < 4000, let utf = String(data: data, encoding: .utf8) {
            lines.append("Response: \(utf)")
        } else if !data.isEmpty {
            lines.append("Response: <\(data.count) bytes>")
        } else {
            lines.append("Response: <empty>")
        }
        print(lines.joined(separator: " | "))
    }
}

private extension Data {
    func prettyJSON(maxLength: Int) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              JSONSerialization.isValidJSONObject(object) else { return nil }
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: options) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        if string.count > maxLength {
            let truncated = String(string.prefix(maxLength)) + " …"
            return truncated
        }
        return string
    }
}
