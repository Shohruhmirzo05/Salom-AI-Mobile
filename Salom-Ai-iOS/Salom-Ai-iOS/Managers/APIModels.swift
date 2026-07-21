//
//  APIModels.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 23/01/25.
//

import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct TokenPair: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
}

// Telegram "login via bot code" — response of /auth/telegram/code/start.
// (keyDecodingStrategy = .convertFromSnakeCase maps bot_url/expires_in.)
struct TelegramCodeStartResponse: Codable {
    let token: String
    let botUrl: String
    let expiresIn: Int
}

struct OAuthUser: Codable {
    let id: Int
    let email: String?
    let displayName: String?
    let avatarUrl: String?
    let authProvider: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case authProvider = "auth_provider"
        case createdAt = "created_at"
    }
}

struct StatusMessageResponse: Decodable {
    let detail: String?

    private enum CodingKeys: String, CodingKey { case detail }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let message = try? container.decode(String.self, forKey: .detail) {
            detail = message
        } else if let failure = try? container.decode(CardChargeFailure.self, forKey: .detail),
                  let data = try? JSONEncoder().encode(failure) {
            // Keep APIError's public shape stable while preserving the structured
            // decline payload for the subscription funnel.
            detail = String(data: data, encoding: .utf8)
        } else {
            detail = nil
        }
    }
}

struct ChatReplyResponse: Codable {
    let reply: String
    let conversationId: Int
    // Note: No custom CodingKeys needed - decoder uses .convertFromSnakeCase
}
/// A web source returned with a search-grounded answer.
struct Citation: Codable, Hashable {
    let title: String
    let url: String
}

struct ChatStreamEvent: Codable {
    let type: String
    let content: String?
    let conversationId: Int?
    let message: String?
    // Web-search extras: stage=="searching_web"/"generating_image" on a "status"
    // event, citations on a "citations" event, upgrade==true on limit events.
    let stage: String?
    let citations: [Citation]?
    let upgrade: Bool?
    // Auto-generated image URL on an "image" event.
    let url: String?
}

struct ChatSavePayload: Codable {
    let conversationId: Int
    let userText: String
    let assistantText: String
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userText = "user_text"
        case assistantText = "assistant_text"
    }
}

struct SearchResult: Codable, Identifiable {
    let id = UUID()
    let title: String?
    let url: String?
    let date: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case url
        case date
    }
}

struct MessageDTO: Codable, Identifiable {
    let id: Int
    let role: MessageRole
    let text: String?
    let createdAt: Date?
    let searchResults: [SearchResult]?
    let perplexityModel: String?
    let imageUrls: [String]?
    let fileUrls: [String]?
    let audioUrl: String?
}

struct ConversationSummary: Codable, Identifiable {
    let id: Int
    let title: String?
    let updatedAt: Date?
    let messageCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case updatedAt = "updated_at"
        case messageCount = "message_count"
    }
}

struct ConversationListResponse: Codable {
    let conversations: [ConversationSummary]
    let total: Int?
}

struct ConversationDetailResponse: Codable {
    let id: Int
    let title: String?
    let autoTitled: Bool
    let createdAt: Date
    let updatedAt: Date
    let messageCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case autoTitled = "auto_titled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case messageCount = "message_count"
    }
}

struct ConversationMessagesResponse: Codable {
    let conversationId: Int
    let messages: [MessageDTO]
    let total: Int
}

//struct ConversationMessageDTO: Codable, Identifiable {
//    let id: Int
//    let role: MessageRole
//    let text: String?
//    let createdAt: Date?
//    let searchResults: [SearchResult]?
//    let perplexityModel: String?
//    let imageUrls: [String]?
//    let fileUrls: [String]?
//    let audioUrl: String?
//    
//    enum CodingKeys: String, CodingKey {
//        case id
//        case role
//        case text
//        case createdAt = "created_at"
//        case searchResults = "search_results"
//        case perplexityModel = "perplexity_model"
//        case imageUrls = "image_urls"
//        case fileUrls = "file_urls"
//        case audioUrl = "audio_url"
//    }
//}

struct MessageSearchHit: Codable, Identifiable {
    let id: Int
    let conversationId: Int?
    let role: MessageRole?
    let text: String?
    let createdAt: Date?
    let conversationTitle: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role
        case text
        case createdAt = "created_at"
        case conversationTitle = "conversation_title"
    }
}

struct SearchResponse: Decodable {
    let results: [MessageSearchHit]
    let total: Int?
    
    init(results: [MessageSearchHit], total: Int? = nil) {
        self.results = results
        self.total = total
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedResults = try container.decodeIfPresent([MessageSearchHit].self, forKey: .results) {
            results = decodedResults
        } else if let messages = try container.decodeIfPresent([MessageSearchHit].self, forKey: .messages) {
            results = messages
        } else {
            results = []
        }
        total = try container.decodeIfPresent(Int.self, forKey: .total)
    }
    
    enum CodingKeys: String, CodingKey {
        case results
        case messages
        case total
    }
}

struct PerplexityUsageResponse: Codable {
    let requestsUsed: Int?
    let requestsLimit: Int?
    let deepResearchUsed: Int?
    let remainingRequests: Int?
}

struct PerplexityModelInfo: Codable, Identifiable {
    var id: String { model }
    let model: String
    let name: String?
    let description: String?
    let inputPricePer1k: Double?
    let outputPricePer1k: Double?
    let useCase: String?
    let note: String?
    

}

struct PerplexityChatResponse: Codable {
    let reply: String
    let conversationId: Int
    let searchResults: [SearchResult]?
    let modelUsed: String?
    

}

struct PerplexityResearchResponse: Codable {
    let report: String
    let searchResults: [SearchResult]?
    let usageInfo: UsageInfo?
    

}

struct UsageInfo: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let costUsd: Double?
    let reasoningEffort: String?
    

}

struct SpeechToTextResponse: Codable {
    let text: String
    let durationSec: Double?
    let costUsd: Double?
    

}

typealias STTResponse = SpeechToTextResponse

struct VoiceChatHeaders {
    let transcript: String?
    let reply: String?
    let conversationId: Int?
    let costUsd: Double?
}

struct SubscriptionPlan: Codable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let priceUzs: Int
    let durationDays: Int?
    let monthlyMessages: Int?
    let monthlyTokens: Int?
    let benefits: [[String: String]]?

    /// Cost per day, derived from priceUzs / durationDays. Never hardcodes 30 —
    /// reads what the admin configured. Falls back to 30 only if API omits it.
    var pricePerDay: Double {
        let days = max(1, durationDays ?? 30)
        return Double(priceUzs) / Double(days)
    }

    /// Is this plan paid (not the free tier)?
    var isPaid: Bool { priceUzs > 0 }

    /// Localized benefit string for a given UI language. Falls back through uz → en.
    func benefit(at index: Int, lang: String) -> String? {
        guard let benefits, index < benefits.count else { return nil }
        let row = benefits[index]
        let short = String(lang.prefix(2)).lowercased()
        return row[short] ?? row["uz"] ?? row["en"] ?? row.values.first
    }
}

// MARK: - Win-back / recovery offer (GET /subscriptions/recovery-offer)

/// Returned only for users who started a payment but never finished and have no
/// active sub. Mirrors the web win-back logic so iOS recovers abandoned payments.
struct RecoveryOfferResponse: Codable {
    let eligible: Bool
    let askSurvey: Bool?
    let offers: [RecoveryOffer]?
}

struct RecoveryOffer: Codable, Identifiable {
    var id: String { promoCode }
    let baseCode: String
    let baseName: String
    let basePrice: Int
    let promoCode: String
    let promoPrice: Int
    let discountPct: Int
    let benefits: [[String: String]]?

    /// Localized benefit string, uz → en fallback (same contract as SubscriptionPlan).
    func benefit(at index: Int, lang: String) -> String? {
        guard let benefits, index < benefits.count else { return nil }
        let row = benefits[index]
        let short = String(lang.prefix(2)).lowercased()
        return row[short] ?? row["uz"] ?? row["en"] ?? row.values.first
    }
}

struct CurrentSubscriptionResponse: Codable {
    let plan: String?
    let active: Bool
    let startedAt: Date?
    let expiresAt: Date?
    

}

struct SubscribeResponse: Codable {
    let provider: String?
    let amountUzs: Int?
    let status: String?
    let checkoutUrl: String?
    let paymentId: Int?
}

/// Status of a single payment transaction (`GET /subscriptions/payments/{id}`).
/// Mirrors the web `PaymentResult` polling source — the authoritative per-payment
/// truth used to decide the post-checkout toast (never inferred from `isPro`).
struct PaymentStatusResponse: Codable {
    let id: Int
    let status: String   // waiting_user | pending | pending_callback | paid | failed | cancelled
    let plan: String?
    let provider: String?
}

struct SettingsPayload: Codable {
    let systemPrompt: String?
    let preferences: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case systemPrompt = "system_prompt"
        case preferences
    }
}

struct UsageStatsResponse: Codable {
    let plan: PlanInfo
    let limits: UsageLimits
    let usage: UsageData
    let resetDate: String?
    

    
    struct PlanInfo: Codable {
        let code: String
        let name: String
        let priceUzs: Int?
        

    }
    
    struct UsageLimits: Codable {
        let fastMessages: Int
        let smartMessages: Int
        let superSmartMessages: Int
        let imageGeneration: Int
        let fileAnalysis: Int
        let voiceMinutes: Int
        let liveQueries: Int
        
        enum CodingKeys: String, CodingKey {
            case fastMessages
            case smartMessages
            case superSmartMessages
            case imageGeneration
            case fileAnalysis
            case voiceMinutes
            case liveQueries
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fastMessages = try container.decodeIfPresent(Int.self, forKey: .fastMessages) ?? 0
            smartMessages = try container.decodeIfPresent(Int.self, forKey: .smartMessages) ?? 0
            superSmartMessages = try container.decodeIfPresent(Int.self, forKey: .superSmartMessages) ?? 0
            imageGeneration = try container.decodeIfPresent(Int.self, forKey: .imageGeneration) ?? 0
            fileAnalysis = try container.decodeIfPresent(Int.self, forKey: .fileAnalysis) ?? 0
            voiceMinutes = try container.decodeIfPresent(Int.self, forKey: .voiceMinutes) ?? 0
            liveQueries = try container.decodeIfPresent(Int.self, forKey: .liveQueries) ?? 0
        }
        
        init(fastMessages: Int = 0, smartMessages: Int = 0, superSmartMessages: Int = 0, imageGeneration: Int = 0, fileAnalysis: Int = 0, voiceMinutes: Int = 0, liveQueries: Int = 0) {
            self.fastMessages = fastMessages
            self.smartMessages = smartMessages
            self.superSmartMessages = superSmartMessages
            self.imageGeneration = imageGeneration
            self.fileAnalysis = fileAnalysis
            self.voiceMinutes = voiceMinutes
            self.liveQueries = liveQueries
        }
    }
    
    struct UsageData: Codable {
        let fastMessages: Int
        let smartMessages: Int
        let superSmartMessages: Int
        let imageGeneration: Int
        let fileAnalysis: Int
        let voiceMinutes: Int
        let liveQueries: Int
        
        enum CodingKeys: String, CodingKey {
            case fastMessages
            case smartMessages
            case superSmartMessages
            case imageGeneration
            case fileAnalysis
            case voiceMinutes
            case liveQueries
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fastMessages = try container.decodeIfPresent(Int.self, forKey: .fastMessages) ?? 0
            smartMessages = try container.decodeIfPresent(Int.self, forKey: .smartMessages) ?? 0
            superSmartMessages = try container.decodeIfPresent(Int.self, forKey: .superSmartMessages) ?? 0
            imageGeneration = try container.decodeIfPresent(Int.self, forKey: .imageGeneration) ?? 0
            fileAnalysis = try container.decodeIfPresent(Int.self, forKey: .fileAnalysis) ?? 0
            voiceMinutes = try container.decodeIfPresent(Int.self, forKey: .voiceMinutes) ?? 0
            liveQueries = try container.decodeIfPresent(Int.self, forKey: .liveQueries) ?? 0
        }
        
        init(fastMessages: Int = 0, smartMessages: Int = 0, superSmartMessages: Int = 0, imageGeneration: Int = 0, fileAnalysis: Int = 0, voiceMinutes: Int = 0, liveQueries: Int = 0) {
            self.fastMessages = fastMessages
            self.smartMessages = smartMessages
            self.superSmartMessages = superSmartMessages
            self.imageGeneration = imageGeneration
            self.fileAnalysis = fileAnalysis
            self.voiceMinutes = voiceMinutes
            self.liveQueries = liveQueries
        }
    }
    

}

struct FileUploadResponse: Codable {
    let url: String
    let filename: String
}

struct DocGenResponse: Codable {
    let url: String
    let filename: String
}

// MARK: - Card Tokenization

struct TokenizeRequestResponse: Codable {
    let requestId: String
    let phoneHint: String
}

struct TokenizeVerifyResponse: Codable {
    let success: Bool
    let subscription: TokenizeSubscriptionInfo?
    let savedCard: TokenizeSavedCard?

    struct TokenizeSubscriptionInfo: Codable {
        let plan: String
        let active: Bool
        let expiresAt: String
        let autoRenew: Bool
    }

    struct TokenizeSavedCard: Codable {
        let id: Int
        let maskedNumber: String
        let phoneHint: String
    }
}

struct CardChargeFailure: Codable {
    let code: String
    let paymentId: Int?
    let planCode: String
    let amountUzs: Int?
    let canRetry: Bool?

    enum CodingKeys: String, CodingKey {
        case code
        case paymentId = "payment_id"
        case planCode = "plan_code"
        case amountUzs = "amount_uzs"
        case canRetry = "can_retry"
    }
}

struct SavedCard: Codable, Identifiable {
    let id: Int
    let maskedNumber: String
    let phoneHint: String
    let createdAt: Date?
}

struct AutoRenewResponse: Codable {
    let ok: Bool
    let autoRenew: Bool
    let savedCardId: Int?
}

struct CancelSubscriptionResponse: Codable {
    let ok: Bool
    let message: String?
    let expiresAt: String?
}

struct CurrentSubscriptionFull: Codable {
    let plan: String?
    let active: Bool
    let startedAt: Date?
    let expiresAt: Date?
    let autoRenew: Bool?
    let savedCard: SavedCard?
    // Payment recovery: a failed auto-renew paused the sub; the saved card can be retried.
    let inRecovery: Bool?
    let recoveryUntil: Date?
    let canRetry: Bool?
}

struct RetryPaymentResponse: Codable {
    let ok: Bool
    let alreadyActive: Bool?
    let expiresAt: String?
}
