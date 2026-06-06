//
//  PresentationModels.swift
//  Salom-Ai-iOS
//
//  Models + API wrapper + localized strings for the AI presentation builder.
//

import Foundation

// MARK: - API models (snake_case mapped via decoder's convertFromSnakeCase)

struct PresoThemeInfo: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let bg: String
    let text: String
    let accent: String
    let dark: Bool
}

struct PresoConfig: Decodable {
    let enabled: Bool
    let maxSlides: Int
    let limit: Int          // -1 unlimited, 0 = upgrade required
    let used: Int
    let canCreate: Bool
    let imagesEnabled: Bool
    let themes: [PresoThemeInfo]
    let defaultTheme: String
}

struct PColumn: Decodable, Hashable {
    let heading: String?
    let bullets: [String]?
}

struct PStat: Decodable, Hashable {
    let value: String?
    let label: String?
}

struct PImage: Decodable, Hashable {
    let url: String?
    let query: String?
    let credit: String?
}

struct PSlide: Decodable, Identifiable, Hashable {
    let id: String?
    let layout: String
    let title: String?
    let subtitle: String?
    let bullets: [String]?
    let left: PColumn?
    let right: PColumn?
    let stats: [PStat]?
    let quote: String?
    let author: String?
    let body: String?
    let image: PImage?
    let notes: String?

    // Stable identity for ForEach even if backend omits id.
    var stableId: String { id ?? "\(layout)-\(title ?? quote ?? "")" }
}

struct Deck: Decodable, Hashable {
    let title: String?
    let slides: [PSlide]
}

struct Presentation: Decodable, Identifiable {
    let id: Int
    let title: String
    let language: String
    let theme: String
    let slideCount: Int
    let status: String        // generating, ready, failed
    let error: String?
    let deck: Deck?
    let createdAt: Date?
    let updatedAt: Date?
}

struct PresentationSummary: Decodable, Identifiable {
    let id: Int
    let title: String
    let language: String
    let theme: String
    let slideCount: Int
    let status: String
    let error: String?
}

private struct PresentationListResponse: Decodable { let presentations: [PresentationSummary] }
struct CreatePresoResponse: Decodable { let id: Int; let status: String }
struct ChatEditResponse: Decodable { let reply: String; let deck: Deck; let slideCount: Int; let title: String }
struct ExportJob: Decodable { let id: Int; let format: String; let status: String; let fileUrl: String?; let error: String? }

// MARK: - Service

enum PresentationService {
    static func config() async throws -> PresoConfig {
        try await APIClient.shared.request(.presentationsConfig, decodeTo: PresoConfig.self)
    }
    static func list() async throws -> [PresentationSummary] {
        try await APIClient.shared.request(.listPresentations, decodeTo: PresentationListResponse.self).presentations
    }
    static func get(_ id: Int) async throws -> Presentation {
        try await APIClient.shared.request(.getPresentation(id: id), decodeTo: Presentation.self)
    }
    static func create(topic: String, language: String, slideCount: Int, theme: String, audience: String?) async throws -> CreatePresoResponse {
        try await APIClient.shared.request(.createPresentation(topic: topic, language: language, slideCount: slideCount, theme: theme, audience: audience), decodeTo: CreatePresoResponse.self)
    }
    static func updateTheme(_ id: Int, theme: String) async throws -> Presentation {
        try await APIClient.shared.request(.updatePresentationTheme(id: id, theme: theme), decodeTo: Presentation.self)
    }
    static func delete(_ id: Int) async throws {
        _ = try await APIClient.shared.requestData(.deletePresentation(id: id))
    }
    static func chat(_ id: Int, instruction: String) async throws -> ChatEditResponse {
        try await APIClient.shared.request(.chatEditPresentation(id: id, instruction: instruction), decodeTo: ChatEditResponse.self)
    }
    static func export(_ id: Int, format: String) async throws -> ExportJob {
        try await APIClient.shared.request(.exportPresentation(id: id, format: format), decodeTo: ExportJob.self)
    }
    static func exportStatus(_ exportId: Int) async throws -> ExportJob {
        try await APIClient.shared.request(.getExportStatus(exportId: exportId), decodeTo: ExportJob.self)
    }
}

// MARK: - Localized strings (self-contained, keyed by app language code)

struct PresoL {
    let lang: String
    init(_ code: String) { self.lang = code }

    // Map app language code → deck language the backend understands.
    var deckLang: String {
        switch lang {
        case "ru": return "ru"
        case "en": return "en"
        default: return "uz"   // uz, uz-Cyrl → uz
        }
    }

    private func pick(_ uz: String, _ ru: String, _ en: String) -> String {
        switch lang {
        case "ru": return ru
        case "en": return en
        default: return uz
        }
    }

    var title: String { pick("AI Presentatsiyalar", "AI Презентации", "AI Presentations") }
    var subtitle: String { pick("Mavzuni yozing — AI siz uchun chiroyli presentatsiya tayyorlaydi", "Напишите тему — ИИ создаст презентацию", "Describe a topic — AI builds a beautiful deck") }
    var topicPlaceholder: String { pick("Masalan: 'Sun'iy intellekt 9-sinf uchun, 10 ta slayd'", "Например: «ИИ для 9 класса, 10 слайдов»", "e.g. 'AI for 9th grade, 10 slides'") }
    var create: String { pick("Yaratish", "Создать", "Create") }
    var creating: String { pick("Yaratilmoqda…", "Создаётся…", "Creating…") }
    var slides: String { pick("slayd", "слайдов", "slides") }
    var audience: String { pick("Auditoriya (ixtiyoriy)", "Аудитория (необяз.)", "Audience (optional)") }
    var theme: String { pick("Mavzu", "Тема", "Theme") }
    var language: String { pick("Til", "Язык", "Language") }
    var myDecks: String { pick("Mening presentatsiyalarim", "Мои презентации", "My presentations") }
    var empty: String { pick("Hali presentatsiya yo'q", "Пока нет презентаций", "No presentations yet") }
    var generating: String { pick("Tayyorlanmoqda…", "Готовится…", "Generating…") }
    var failed: String { pick("Xatolik", "Ошибка", "Failed") }
    var delete: String { pick("O'chirish", "Удалить", "Delete") }
    var buildingDeck: String { pick("AI presentatsiyaingizni tayyorlamoqda. Bu bir necha soniya oladi…", "ИИ готовит вашу презентацию…", "AI is building your deck…") }
    var present: String { pick("Namoyish", "Показ", "Present") }
    var export: String { pick("Yuklab olish", "Скачать", "Export") }
    var exporting: String { pick("Tayyorlanmoqda…", "Готовится…", "Preparing…") }
    var download: String { pick("Yuklab olish", "Скачать", "Download") }
    var share: String { pick("Ulashish", "Поделиться", "Share") }
    var editWithAI: String { pick("AI bilan tahrirlash", "Редактировать с ИИ", "Edit with AI") }
    var chatPlaceholder: String { pick("Nimani o'zgartiray? Masalan: '3-slaydni qisqartir'", "Что изменить? Напр.: «сократи слайд 3»", "What to change? e.g. 'shorten slide 3'") }
    var applying: String { pick("Qo'llanmoqda…", "Применяется…", "Applying…") }
    var back: String { pick("Orqaga", "Назад", "Back") }
    var retry: String { pick("Qayta urinish", "Повторить", "Retry") }
    var premiumTitle: String { pick("AI Presentatsiyalar — Premium", "AI Презентации — Premium", "AI Presentations — Premium") }
    var premiumDesc: String { pick("Bir jumla yozing — AI to'liq, chiroyli presentatsiya tayyorlaydi. PowerPoint (PPTX) va PDF yuklab oling, AI bilan suhbatlashib tahrirlang.", "Одна фраза — и ИИ создаёт презентацию. Экспорт в PPTX и PDF, редактирование через чат.", "Write one sentence — AI builds a full deck. Export to PPTX & PDF, edit by chatting with AI.") }
    var upgrade: String { pick("Pro rejaga o'tish", "Перейти на Pro", "Upgrade to Pro") }
    var limitReached: String { pick("Bu oy uchun limit tugadi. Pro rejada ko'proq yarating.", "Лимит на месяц исчерпан. На Pro — больше.", "Monthly limit reached. Upgrade for more.") }
    var remaining: String { pick("qoldi", "осталось", "left") }
    var unlimited: String { pick("Cheksiz", "Безлимит", "Unlimited") }
}
