//
//  WorkModels.swift
//  Salom-Ai-iOS
//
//  Models + API wrapper + localized strings for "Ish" (Salom AI Work) — the guided
//  professional-document task studio. Mirrors PresentationModels.swift.
//

import Foundation

// MARK: - Localizable string object ({uz, ru, en} from the backend)

struct LocStr: Decodable, Hashable {
    let uz: String
    let ru: String?
    let en: String?

    /// Pick by app language code. Backend copy currently ships as uz/ru/en, so
    /// Cyrillic Uzbek is derived from the canonical Uzbek copy on-device.
    func pick(_ code: String) -> String {
        switch code {
        case "ru": return ru ?? uz
        case "en": return en ?? uz
        case "kr", "uz-Cyrl": return UzCyrillic.toCyrillic(uz)
        default: return uz
        }
    }
}

// MARK: - API models (snake_case mapped via decoder's convertFromSnakeCase)

struct WorkTaskInput: Decodable, Hashable {
    let key: String
    let label: LocStr
    let type: String              // text | textarea | select | number
    let required: Bool
    let placeholder: LocStr?
    let options: [LocStr]?
}

struct WorkTask: Decodable, Identifiable, Hashable {
    let id: String
    let segment: String
    let title: LocStr
    let subtitle: LocStr
    let icon: String
    let output: String            // docx | xlsx
    let inputs: [WorkTaskInput]
    let blogSlug: String?
}

struct WorkSegment: Decodable, Identifiable, Hashable {
    let id: String
    let label: LocStr
}

struct WorkAccess: Decodable {
    let mode: String              // locked | full
    let canCreate: Bool
    let canExport: Bool
    let monthlyLimit: Int
    let monthlyUsed: Int
}

struct WorkTasksResponse: Decodable {
    let segments: [WorkSegment]
    let tasks: [WorkTask]
    let access: WorkAccess
}

struct WorkDoc: Decodable, Identifiable {
    let id: Int
    let templateId: String?
    let segment: String?
    let title: String
    let language: String?
    let outputFormat: String      // docx | xlsx
    let status: String            // generating | ready | failed
    let error: String?
    let content: String?
    let locked: Bool?
    let mode: String?
    let canExport: Bool?
    let createdAt: Date?
    let updatedAt: Date?
}

private struct WorkListResponse: Decodable { let work: [WorkDoc] }
struct CreateWorkResponse: Decodable { let id: Int; let status: String }
struct WorkChatResponse: Decodable { let reply: String; let content: String; let title: String }
struct WorkExportJob: Decodable { let id: Int; let format: String; let status: String; let fileUrl: String?; let error: String? }

// MARK: - Service

enum WorkService {
    static func tasks() async throws -> WorkTasksResponse {
        try await APIClient.shared.request(.workTasks, decodeTo: WorkTasksResponse.self)
    }
    static func list() async throws -> [WorkDoc] {
        try await APIClient.shared.request(.listWork, decodeTo: WorkListResponse.self).work
    }
    static func get(_ id: Int) async throws -> WorkDoc {
        try await APIClient.shared.request(.getWork(id: id), decodeTo: WorkDoc.self)
    }
    static func generate(taskId: String, inputs: [String: String], language: String) async throws -> CreateWorkResponse {
        try await APIClient.shared.request(.generateWorkTask(taskId: taskId, inputs: inputs, language: language), decodeTo: CreateWorkResponse.self)
    }
    static func chat(_ id: Int, instruction: String) async throws -> WorkChatResponse {
        try await APIClient.shared.request(.workChat(id: id, instruction: instruction), decodeTo: WorkChatResponse.self)
    }
    static func export(_ id: Int, format: String) async throws -> WorkExportJob {
        try await APIClient.shared.request(.workExport(id: id, format: format), decodeTo: WorkExportJob.self)
    }
    static func exportStatus(_ exportId: Int) async throws -> WorkExportJob {
        try await APIClient.shared.request(.workExportStatus(exportId: exportId), decodeTo: WorkExportJob.self)
    }
}

// MARK: - Localized chrome (mirrors PresoL)

struct IshL {
    let lang: String
    init(_ code: String) { self.lang = code }

    /// Generation language the backend understands. uz-Cyrl → "kr" so the document
    /// is produced in Cyrillic; others map directly.
    var docLang: String {
        switch lang {
        case "ru": return "ru"
        case "en": return "en"
        case "uz-Cyrl", "kr": return "kr"
        default: return "uz"
        }
    }

    private func pick(_ uz: String, _ ru: String, _ en: String) -> String {
        switch lang {
        case "ru": return ru
        case "en": return en
        case "kr", "uz-Cyrl": return UzCyrillic.toCyrillic(uz)
        default: return uz
        }
    }

    var title: String { pick("Ish — hujjatlar", "Работа — документы", "Work — documents") }
    var subtitle: String { pick("Kasbiy hujjatlarni bir necha daqiqada tayyorlang", "Готовьте рабочие документы за минуты", "Prepare work documents in minutes") }
    var create: String { pick("Hujjatni yaratish", "Создать документ", "Create document") }
    var creating: String { pick("Tayyorlanmoqda…", "Готовится…", "Generating…") }
    var docGenerating: String { pick("Hujjat tayyorlanmoqda…", "Документ готовится…", "Preparing document…") }
    var select: String { pick("Tanlang…", "Выберите…", "Select…") }
    var recent: String { pick("So'nggi hujjatlar", "Недавние документы", "Recent documents") }
    var export: String { pick("Yuklab olish", "Скачать", "Download") }
    var share: String { pick("Ulashish", "Поделиться", "Share") }
    var editWithAI: String { pick("AI bilan tahrirlash", "Редактировать с ИИ", "Edit with AI") }
    var chatPlaceholder: String { pick("Nimani o'zgartiray? Masalan: 'narxni 3 mln qil'", "Что изменить? Напр.: «цена 3 млн»", "What to change? e.g. 'price 3M'") }
    var applying: String { pick("Qo'llanmoqda…", "Применяется…", "Applying…") }
    var back: String { pick("Orqaga", "Назад", "Back") }
    var failed: String { pick("Xatolik", "Ошибка", "Failed") }
    var required: String { pick("Bu maydon majburiy", "Обязательное поле", "This field is required") }
    var lockedTitle: String { pick("Ish hujjatlari — Pro tarifida", "Рабочие документы — в Pro", "Work documents — Pro only") }
    var lockedDesc: String { pick("Tijorat taklifi, shartnoma, hisob-faktura va boshqa hujjatlarni yaratish uchun Pro tarifiga o'ting.", "Оформите Pro, чтобы создавать КП, договоры, счета и др.", "Upgrade to Pro to create proposals, contracts, invoices and more.") }
    var upgrade: String { pick("Pro rejaga o'tish", "Перейти на Pro", "Upgrade to Pro") }
    var thisMonth: String { pick("Bu oy", "В этом месяце", "This month") }
    var limitReached: String { pick("Bu oy uchun limit tugadi.", "Лимит на месяц исчерпан.", "Monthly limit reached.") }
    var general: String { pick("Umumiy AI suhbat", "Обычный AI-чат", "General AI chat") }
}
