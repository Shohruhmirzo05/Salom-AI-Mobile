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
                        // Read error body from the byte stream
                        var errorBody = Data()
                        for try await byte in bytes {
                            errorBody.append(byte)
                            if errorBody.count > 4096 { break }
                        }
                        var message = "Stream failed"
                        if let json = try? JSONSerialization.jsonObject(with: errorBody) as? [String: Any] {
                            if let detail = json["detail"] as? String {
                                message = detail
                            } else if let detail = json["detail"] as? [String: Any] {
                                message = detail["message"] as? String ?? "Stream failed"
                                if let code = detail["code"] as? String {
                                    message = "[\(code)] \(message)"
                                }
                            }
                        }
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
        request.timeoutInterval = endpoint.timeoutInterval
        
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
        case oauthVerify(provider: OAuthProvider, idToken: String, platform: String = "ios")
        case oauthUser
        // Telegram "login via bot code" (no Mini App initData on native iOS)
        case telegramCodeStart(phone: String)
        case telegramCodeVerify(token: String, code: String, platform: String = "ios")
        case updateProfile(language: String?, displayName: String?, avatarUrl: String?)
        case updatePlatform(platform: String)
        
        // Chat
        case chat(conversationId: Int?, text: String, projectId: Int?, model: String?, attachments: [String]?)
        case chatStream(conversationId: Int?, text: String, projectId: Int?, model: String?, attachments: [String]?, regenerate: Bool, webSearch: Bool, platform: String?)
        case generateImage(conversationId: Int?, prompt: String, projectId: Int?, referenceImages: [String]?, regenerate: Bool, replaceImageUrl: String?)
        case saveChat(conversationId: Int, userText: String, assistantText: String)
        case uploadFile(data: Data, filename: String)
        case uploadReferenceImage(data: Data, filename: String, contentType: String)
        
        // Perplexity
        case perplexityChat(conversationId: Int?, text: String, model: String?, searchMode: String?)
        case perplexityResearch(query: String, reasoningEffort: String)
        case perplexityUsage
        case getModels
        
        // Voice
        case stt(audio: Data, filename: String, language: String?)
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
        case paymentStatus(id: Int)
        case getUsageStats
        case autoRenew(cardId: Int?, enabled: Bool)
        case cancelSubscription
        case retryPayment

        // Cards
        case tokenizeCardRequest(cardNumber: String, expireDate: String)
        case tokenizeCardVerify(requestId: String, smsCode: Int, planCode: String)
        case savedCards
        case deleteCard(id: Int)
        
        // Settings
        case getSettings
        case updateSettings(SettingsPayload)
        
        // Notifications
        case notifications(limit: Int, offset: Int)
        case unreadNotificationCount
        case markNotificationRead(id: Int)
        case markAllNotificationsRead

        // Account
        case deleteAccount
        case sendFeedback(content: String)

        // Presentations
        case presentationsConfig
        case listPresentations
        case getPresentation(id: Int)
        case createPresentation(topic: String, language: String, slideCount: Int, theme: String, audience: String?)
        case updatePresentationTheme(id: Int, theme: String)
        case deletePresentation(id: Int)
        case chatEditPresentation(id: Int, instruction: String)
        case exportPresentation(id: Int, format: String)
        case getExportStatus(exportId: Int)

        // Referats (AI referat / insho writer)
        case referatsConfig
        case listReferats
        case getReferat(id: Int)
        case createReferat(topic: String, language: String, targetWords: Int, audience: String?)
        case deleteReferat(id: Int)
        case chatEditReferat(id: Int, instruction: String)
        case exportReferat(id: Int, format: String)
        case getReferatExportStatus(exportId: Int)

        // Ish / Work (task studio)
        case workTasks
        case generateWorkTask(taskId: String, inputs: [String: String], language: String)
        case listWork
        case getWork(id: Int)
        case workChat(id: Int, instruction: String)
        case workExport(id: Int, format: String)
        case workExportStatus(exportId: Int)
        case getWorkProfile
        case updateWorkProfile(fields: [String: String])

        // DTM (adaptive test-prep)
        case dtmSubjects
        case dtmTopics(subject: String)
        case dtmLevels(subject: String)
        case dtmQuiz(subject: String, topic: String?, difficulty: String?)
        case dtmAnswer(questionId: Int, chosenKey: String)
        case dtmProgress

        // Win-back + retention
        case recoveryOffer
        case cancelSurvey(reason: String)
        case savePersona(role: String?, goals: [String])
        case accountStreak

        // Push registration (fixes iOS notifications: register OneSignal id)
        case registerPushDevice(token: String, platform: String)

        // On-demand document generation (server-renders a clean PDF/Word/Excel)
        case generateDocument(text: String, format: String)

        fileprivate var method: HTTPMethod {
            switch self {
            case .listConversations, .getConversation, .getConversationMessages, .perplexityUsage, .currentSubscription, .getSettings, .getModels, .getUsageStats, .listPlans, .oauthUser, .savedCards, .paymentStatus, .notifications, .unreadNotificationCount,
                 .presentationsConfig, .listPresentations, .getPresentation, .getExportStatus,
                 .referatsConfig, .listReferats, .getReferat, .getReferatExportStatus,
                 .workTasks, .listWork, .getWork, .workExportStatus, .getWorkProfile,
                 .dtmSubjects, .dtmTopics, .dtmLevels, .dtmQuiz, .dtmProgress, .recoveryOffer, .accountStreak:
                return .get
            case .deleteConversation, .deleteAccount, .deleteCard, .deletePresentation, .deleteReferat:
                return .delete
            case .updateSettings, .updateProfile, .updatePresentationTheme, .updateWorkProfile:
                return .put
            case .updatePlatform:
                return .post
            default:
                return .post
            }
        }
        
        fileprivate var requiresAuth: Bool {
            switch self {
            case .requestOTP, .verifyOTP, .refresh, .oauthVerify, .telegramCodeStart, .telegramCodeVerify:
                return false
            default:
                return true
            }
        }
        
        fileprivate var isMultipart: Bool {
            switch self {
            case .uploadFile, .uploadReferenceImage, .stt, .chatVoice:
                return true
            default:
                return false
            }
        }

        fileprivate var timeoutInterval: TimeInterval {
            switch self {
            case .generateImage, .chatStream:
                // Image queues and the first streamed token can legitimately take
                // longer than the generic API timeout on a busy provider.
                return 210
            case .uploadReferenceImage, .uploadFile:
                return 90
            default:
                return 60
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
            case .uploadReferenceImage:
                return "/images/upload"
            case .generateDocument:
                return "/documents/generate"
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
            case .telegramCodeStart:
                return "/auth/telegram/code/start"
            case .telegramCodeVerify:
                return "/auth/telegram/code/verify"
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
            case .paymentStatus(let id):
                return "/subscriptions/payments/\(id)"
            case .getUsageStats:
                return "/subscriptions/usage"
            case .autoRenew:
                return "/subscriptions/auto-renew"
            case .cancelSubscription:
                return "/subscriptions/cancel"
            case .retryPayment:
                return "/subscriptions/retry-payment"
            case .tokenizeCardRequest:
                return "/cards/tokenize/request"
            case .tokenizeCardVerify:
                return "/cards/tokenize/verify"
            case .savedCards:
                return "/cards"
            case .deleteCard(let id):
                return "/cards/\(id)"
            case .notifications:
                return "/notifications"
            case .unreadNotificationCount:
                return "/notifications/unread-count"
            case .markNotificationRead(let id):
                return "/notifications/\(id)/read"
            case .markAllNotificationsRead:
                return "/notifications/read-all"
            case .getSettings, .updateSettings:
                return "/settings"
            case .deleteAccount:
                return "/account"
            case .sendFeedback:
                return "/feedback"
            case .presentationsConfig:
                return "/presentations/config"
            case .listPresentations, .createPresentation:
                return "/presentations"
            case .getPresentation(let id), .updatePresentationTheme(let id, _), .deletePresentation(let id):
                return "/presentations/\(id)"
            case .chatEditPresentation(let id, _):
                return "/presentations/\(id)/chat"
            case .exportPresentation(let id, _):
                return "/presentations/\(id)/export"
            case .getExportStatus(let exportId):
                return "/presentations/exports/\(exportId)"
            case .referatsConfig:
                return "/referats/config"
            case .listReferats, .createReferat:
                return "/referats"
            case .getReferat(let id), .deleteReferat(let id):
                return "/referats/\(id)"
            case .chatEditReferat(let id, _):
                return "/referats/\(id)/chat"
            case .exportReferat(let id, _):
                return "/referats/\(id)/export"
            case .getReferatExportStatus(let exportId):
                return "/referats/exports/\(exportId)"
            case .workTasks:
                return "/tasks"
            case .generateWorkTask(let taskId, _, _):
                return "/tasks/\(taskId)/generate"
            case .listWork:
                return "/work"
            case .getWork(let id):
                return "/work/\(id)"
            case .workChat(let id, _):
                return "/work/\(id)/chat"
            case .workExport(let id, _):
                return "/work/\(id)/export"
            case .workExportStatus(let exportId):
                return "/work/exports/\(exportId)"
            case .getWorkProfile, .updateWorkProfile:
                return "/settings/profile"
            case .dtmSubjects:
                return "/dtm/subjects"
            case .dtmTopics:
                return "/dtm/topics"
            case .dtmLevels:
                return "/dtm/levels"
            case .dtmQuiz:
                return "/dtm/quiz"
            case .dtmAnswer:
                return "/dtm/answer"
            case .dtmProgress:
                return "/dtm/progress"
            case .recoveryOffer:
                return "/subscriptions/recovery-offer"
            case .cancelSurvey:
                return "/subscriptions/cancel-survey"
            case .savePersona:
                return "/account/persona"
            case .accountStreak:
                return "/account/streak"
            case .registerPushDevice:
                return "/notifications/device"
            }
        }

        private var queryItems: [URLQueryItem] {
            switch self {
            case .dtmTopics(let subject), .dtmLevels(let subject):
                return [URLQueryItem(name: "subject", value: subject)]
            case .dtmQuiz(let subject, let topic, let difficulty):
                var q = [URLQueryItem(name: "subject", value: subject)]
                if let topic, !topic.isEmpty { q.append(URLQueryItem(name: "topic", value: topic)) }
                if let difficulty, !difficulty.isEmpty { q.append(URLQueryItem(name: "difficulty", value: difficulty)) }
                return q
            case .listConversations(let limit, let offset):
                return [
                    URLQueryItem(name: "limit", value: "\(limit)"),
                    URLQueryItem(name: "offset", value: "\(offset)")
                ]
            case .notifications(let limit, let offset):
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
            case .oauthVerify(let provider, let idToken, let platform):
                return ["provider": provider.rawValue, "id_token": idToken, "platform": platform]
            case .telegramCodeStart(let phone):
                return ["phone": phone]
            case .telegramCodeVerify(let token, let code, let platform):
                return ["token": token, "code": code, "platform": platform]
            case .dtmAnswer(let questionId, let chosenKey):
                return ["question_id": questionId, "chosen_key": chosenKey]
            case .cancelSurvey(let reason):
                var body: [String: Any] = ["reason": reason]
                if let id = PaywallAttributionStore.shared.paywallID { body["paywall_id"] = id }
                return body
            case .savePersona(let role, let goals):
                var b: [String: Any] = ["goals": goals]
                if let role { b["role"] = role }
                return b
            case .registerPushDevice(let token, let platform):
                return ["token": token, "platform": platform]
            case .chat(let conversationId, let text, let projectId, let model, let attachments):
                var body: [String: Any] = ["text": text]
                if let conversationId { body["conversation_id"] = conversationId }
                if let projectId { body["project_id"] = projectId }
                if let model { body["model"] = model }
                if let attachments { body["attachments"] = attachments }
                return body
            case .chatStream(let conversationId, let text, let projectId, let model, let attachments, let regenerate, let webSearch, let platform):
                var body: [String: Any] = ["text": text]
                if let conversationId { body["conversation_id"] = conversationId }
                if let projectId { body["project_id"] = projectId }
                if let model { body["model"] = model }
                if let attachments { body["attachments"] = attachments }
                if regenerate { body["regenerate"] = true }
                // true = force web search; omitted = smart auto-detect on the backend.
                if webSearch { body["web_search"] = true }
                if let platform { body["platform"] = platform }
                return body
            case .generateImage(let conversationId, let prompt, let projectId, let referenceImages, let regenerate, let replaceImageUrl):
                var params: [String: Any] = ["prompt": prompt]
                if let conversationId { params["conversation_id"] = conversationId }
                if let projectId { params["project_id"] = projectId }
                if let referenceImages, !referenceImages.isEmpty { params["reference_images"] = referenceImages }
                if regenerate { params["regenerate"] = true }
                if let replaceImageUrl { params["replace_image_url"] = replaceImageUrl }
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
                var body: [String: Any] = ["plan": plan, "provider": provider]
                PaywallAttributionStore.shared.requestFields.forEach { body[$0.key] = $0.value }
                return body
            case .autoRenew(let cardId, let enabled):
                var body: [String: Any] = ["enabled": enabled]
                if let cardId { body["card_id"] = cardId }
                return body
            case .cancelSubscription, .retryPayment:
                return [:]
            case .tokenizeCardRequest(let cardNumber, let expireDate):
                return ["card_number": cardNumber, "expire_date": expireDate]
            case .tokenizeCardVerify(let requestId, let smsCode, let planCode):
                var body: [String: Any] = ["request_id": requestId, "sms_code": smsCode, "plan_code": planCode]
                PaywallAttributionStore.shared.requestFields.forEach { body[$0.key] = $0.value }
                return body
            case .updateSettings(let payload):
                var body: [String: Any] = [:]
                if let prompt = payload.systemPrompt { body["system_prompt"] = prompt }
                if let preferences = payload.preferences { body["preferences"] = preferences }
                return body
            case .updateProfile(let language, let displayName, let avatarUrl):
                var body: [String: Any] = [:]
                if let language { body["language"] = language }
                if let displayName { body["display_name"] = displayName }
                if let avatarUrl { body["avatar_url"] = avatarUrl }
                return body
            case .generateDocument(let text, let format):
                return ["text": text, "format": format]
            case .updatePlatform(let platform):
                return ["platform": platform]
            case .sendFeedback(let content):
                return ["content": content, "platform": "ios"]
            case .tts(let text), .ttsStream(let text):
                return ["text": text]
            case .createPresentation(let topic, let language, let slideCount, let theme, let audience):
                var body: [String: Any] = ["topic": topic, "language": language, "slide_count": slideCount, "theme": theme]
                if let audience, !audience.isEmpty { body["audience"] = audience }
                return body
            case .updatePresentationTheme(_, let theme):
                return ["theme": theme]
            case .chatEditPresentation(_, let instruction):
                return ["instruction": instruction]
            case .exportPresentation(_, let format):
                return ["format": format]
            case .createReferat(let topic, let language, let targetWords, let audience):
                var body: [String: Any] = ["topic": topic, "language": language, "target_words": targetWords]
                if let audience, !audience.isEmpty { body["audience"] = audience }
                return body
            case .chatEditReferat(_, let instruction):
                return ["instruction": instruction]
            case .exportReferat(_, let format):
                return ["format": format]
            case .generateWorkTask(_, let inputs, let language):
                return ["inputs": inputs, "language": language]
            case .workChat(_, let instruction):
                return ["instruction": instruction]
            case .workExport(_, let format):
                return ["format": format]
            case .updateWorkProfile(let fields):
                return fields
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
            case .uploadFile(let data, let filename):
                append("--\(boundary)\r\n")
                append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
                append("Content-Type: application/octet-stream\r\n\r\n")
                body.append(data)
                append("\r\n")
            case .uploadReferenceImage(let data, let filename, let contentType):
                append("--\(boundary)\r\n")
                append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
                append("Content-Type: \(contentType)\r\n\r\n")
                body.append(data)
                append("\r\n")
            case .stt(let data, let filename, let language):
                append("--\(boundary)\r\n")
                append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
                append("Content-Type: application/octet-stream\r\n\r\n")
                body.append(data)
                append("\r\n")
                // Prioritise the user's spoken/UI language (backend defaults to Uzbek).
                if let language {
                    append("--\(boundary)\r\n")
                    append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
                    append("\(language)\r\n")
                }
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
