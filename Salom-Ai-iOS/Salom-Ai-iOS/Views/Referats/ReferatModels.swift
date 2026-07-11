//
//  ReferatModels.swift
//  Salom-Ai-iOS
//
//  Models + API wrapper + localized strings for the AI referat / insho writer.
//  Mirrors the web /referats feature and the Presentations iOS module.
//

import Foundation

// MARK: - API models (snake_case mapped via decoder's convertFromSnakeCase)

struct ReferatSection: Decodable, Identifiable, Hashable {
    let id: String?
    let heading: String
    let paragraphs: [String]
    var stableId: String { id ?? heading }
}

struct ReferatDoc: Decodable, Hashable {
    let title: String?
    let sections: [ReferatSection]
    let references: [String]?
}

struct Referat: Decodable, Identifiable {
    let id: Int
    let title: String
    let language: String
    let wordCount: Int
    let status: String            // generating, ready, failed
    let error: String?
    let doc: ReferatDoc?
    let createdAt: Date?
    let updatedAt: Date?
    // "show, don't give": free users get the doc trimmed server-side.
    let lockedSections: Int?
    let mode: String?             // preview | full
    let canExport: Bool?
    let watermark: Bool?
}

struct ReferatSummary: Decodable, Identifiable {
    let id: Int
    let title: String
    let language: String
    let wordCount: Int
    let status: String
    let error: String?
}

struct ReferatConfig: Decodable {
    let enabled: Bool
    let maxWords: Int
    let limit: Int                // -1 unlimited, 0 = upgrade required
    let used: Int
    let canCreate: Bool
    let mode: String?
    let canExport: Bool?
    let previewSections: Int?
    let freeDaily: Int?
    let freeUsedToday: Int?
}

private struct ReferatListResponse: Decodable { let referats: [ReferatSummary] }
struct CreateReferatResponse: Decodable { let id: Int; let status: String }
struct ReferatChatResponse: Decodable { let reply: String; let doc: ReferatDoc; let wordCount: Int; let title: String }
struct ReferatExportJob: Decodable { let id: Int; let format: String; let status: String; let fileUrl: String?; let error: String? }

// MARK: - Service

enum ReferatService {
    static func config() async throws -> ReferatConfig {
        try await APIClient.shared.request(.referatsConfig, decodeTo: ReferatConfig.self)
    }
    static func list() async throws -> [ReferatSummary] {
        try await APIClient.shared.request(.listReferats, decodeTo: ReferatListResponse.self).referats
    }
    static func get(_ id: Int) async throws -> Referat {
        try await APIClient.shared.request(.getReferat(id: id), decodeTo: Referat.self)
    }
    static func create(topic: String, language: String, targetWords: Int, audience: String?) async throws -> CreateReferatResponse {
        try await APIClient.shared.request(.createReferat(topic: topic, language: language, targetWords: targetWords, audience: audience), decodeTo: CreateReferatResponse.self)
    }
    static func delete(_ id: Int) async throws {
        _ = try await APIClient.shared.requestData(.deleteReferat(id: id))
    }
    static func chat(_ id: Int, instruction: String) async throws -> ReferatChatResponse {
        try await APIClient.shared.request(.chatEditReferat(id: id, instruction: instruction), decodeTo: ReferatChatResponse.self)
    }
    static func export(_ id: Int, format: String) async throws -> ReferatExportJob {
        try await APIClient.shared.request(.exportReferat(id: id, format: format), decodeTo: ReferatExportJob.self)
    }
    static func exportStatus(_ exportId: Int) async throws -> ReferatExportJob {
        try await APIClient.shared.request(.getReferatExportStatus(exportId: exportId), decodeTo: ReferatExportJob.self)
    }
}

// MARK: - Localized strings (self-contained, keyed by app language code)

struct ReferatL {
    let lang: String
    init(_ code: String) { self.lang = code }

    var docLang: String {
        switch lang {
        case "ru": return "ru"
        case "en": return "en"
        default: return "uz"
        }
    }

    private func pick(_ uz: String, _ ru: String, _ en: String) -> String {
        switch lang {
        case "ru": return ru
        case "en": return en
        default: return uz
        }
    }

    var title: String { pick("AI Referat", "AI Реферат", "AI Referat") }
    var subtitle: String { pick("Mavzuni yozing — AI tayyor referat va kurs ishi yozib beradi", "Напишите тему — ИИ напишет реферат или курсовую", "Describe a topic — AI writes a full referat / coursework") }
    var topicPlaceholder: String { pick("Masalan: 'Sun'iy intellektning ta'limdagi o'rni'", "Например: «Роль ИИ в образовании»", "e.g. 'The role of AI in education'") }
    var audience: String { pick("Daraja (ixtiyoriy)", "Уровень (необяз.)", "Level (optional)") }
    var length: String { pick("Hajmi", "Объём", "Length") }
    var words: String { pick("so'z", "слов", "words") }
    var language: String { pick("Til", "Язык", "Language") }
    var create: String { pick("Yozib berish", "Написать", "Write") }
    var creating: String { pick("Yozilmoqda…", "Пишется…", "Writing…") }
    var myReferats: String { pick("Mening referatlarim", "Мои рефераты", "My referats") }
    var empty: String { pick("Hali referat yo'q", "Пока нет рефератов", "No referats yet") }
    var generating: String { pick("Tayyorlanmoqda…", "Готовится…", "Generating…") }
    var failed: String { pick("Xatolik", "Ошибка", "Failed") }
    var delete: String { pick("O'chirish", "Удалить", "Delete") }
    var back: String { pick("Orqaga", "Назад", "Back") }
    var download: String { pick("Yuklab olish", "Скачать", "Download") }
    var exporting: String { pick("Tayyorlanmoqda…", "Готовится…", "Preparing…") }
    var building: String { pick("AI referatingizni yozmoqda. Bir necha soniya…", "ИИ пишет ваш реферат. Несколько секунд…", "AI is writing your referat. A few seconds…") }
    var editWithAI: String { pick("AI bilan tahrirlash", "Редактировать с ИИ", "Edit with AI") }
    var chatPlaceholder: String { pick("Nimani o'zgartiray? Masalan: 'Kirishni kengaytir', 'Xulosa qo'sh'", "Что изменить? Напр.: «расширь введение», «добавь вывод»", "What to change? e.g. 'expand the intro', 'add a conclusion'") }
    var applying: String { pick("Qo'llanmoqda…", "Применяется…", "Applying…") }
    var references: String { pick("Foydalanilgan adabiyotlar", "Источники", "References") }
    var lockedTitle: String { pick("To'liq referat 🔒", "Полный реферат 🔒", "Full referat 🔒") }
    var lockedDesc: String { pick("Qolgan bo'limlar, manbalar va Word (DOCX) yuklab olish Pro tarifida.", "Остальные разделы, источники и Word (DOCX) — на Pro.", "Remaining sections, references and Word (DOCX) export are on Pro.") }
    var upgrade: String { pick("Pro tarifga o'tish", "Перейти на Pro", "Upgrade to Pro") }
    var premiumTitle: String { pick("AI Referat — Premium", "AI Реферат — Premium", "AI Referat — Premium") }
    var premiumDesc: String { pick("Mavzuni yozing — AI to'liq referat va kurs ishini yozadi. Word (DOCX) va PDF yuklab oling, AI bilan tahrirlang.", "Напишите тему — ИИ пишет полный реферат. Экспорт в Word и PDF, правки через чат.", "Write a topic — AI writes a full referat. Export to Word & PDF, edit with AI.") }
    var freeDailyDone: String { pick("Bugungi bepul referat tayyor. Ko'proq uchun Pro yoki ertaga qayting.", "Бесплатный реферат на сегодня готов. Больше — на Pro, или завтра.", "Today's free referat is ready. Upgrade to Pro for more, or come back tomorrow.") }
    var previewBadge: String { pick("Ko'rib chiqish", "Предпросмотр", "Preview") }
    var remaining: String { pick("qoldi", "осталось", "left") }
    var unlimited: String { pick("Cheksiz", "Безлимит", "Unlimited") }
}
