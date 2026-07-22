import Foundation
import Combine

/// Used only by the subscription-management screen. Contextual paywalls remain
/// visual-first and deliberately do not render this comparison list.
struct PlanCompareFeature: Identifiable {
    let id = UUID()
    let label: String
    let proOnly: Bool
}

let planCompareFeatures: [PlanCompareFeature] = [
    .init(label: "📊 Taqdimot, referat va DTM", proOnly: false),
    .init(label: "🎨 Rasm yaratish va ovozli rejim", proOnly: false),
    .init(label: "🧠 Eng kuchli AI — Super Aqlli", proOnly: true),
    .init(label: "🚀 Yuqori limitlar — ko‘proq rasm va ovoz", proOnly: true),
    .init(label: "👑 Hamma imkoniyat — cheklovsiz", proOnly: true),
]

/// Stable conversion surfaces shared with web/Telegram analytics. Keep raw values
/// backward compatible: they are persisted in payment attribution and admin reports.
enum PaywallContextID: String, CaseIterable, Identifiable {
    case general
    case presentationExport = "presentation_export"
    case referatExport = "referat_export"
    case accountingReport = "accounting_report"
    case commercialOffer = "commercial_offer"
    case contractDraft = "contract_draft"
    case businessPlan = "business_plan"
    case invoiceExport = "invoice_export"
    case lessonPlan = "lesson_plan"
    case dtmDailyLimit = "dtm_daily_limit"
    case dtmScorePlan = "dtm_score_plan"
    case imageReferenceEdit = "image_reference_edit"
    case imageGenerationLimit = "image_generation_limit"
    case voiceSessionLimit = "voice_session_limit"
    case fileAnalysisLimit = "file_analysis_limit"
    case smartModelUpgrade = "smart_model_upgrade"
    case studentFirstValue = "student_first_value"
    case teacherFirstValue = "teacher_first_value"
    case businessFirstValue = "business_first_value"
    case officeFirstValue = "office_first_value"
    case paymentRecovery = "payment_recovery"

    var id: String { rawValue }

    /// Image-led compositions used by the contextual paywall. The value proof
    /// changes with the job the user just completed instead of showing the
    /// same generic subscription card for every feature.
    var artStyle: PaywallArtStyle {
        switch self {
        case .general: .toolkit
        case .presentationExport: .presentation
        case .referatExport: .document
        case .accountingReport: .beforeAfter
        case .commercialOffer: .proposal
        case .contractDraft: .secureDocument
        case .businessPlan: .roadmap
        case .invoiceExport: .invoice
        case .lessonPlan: .lesson
        case .dtmDailyLimit: .quota
        case .dtmScorePlan: .score
        case .imageReferenceEdit: .imageCompare
        case .imageGenerationLimit: .gallery
        case .voiceSessionLimit: .voice
        case .fileAnalysisLimit: .fileAnalysis
        case .smartModelUpgrade: .modelCompare
        case .studentFirstValue: .student
        case .teacherFirstValue: .teacher
        case .businessFirstValue: .business
        case .officeFirstValue: .office
        case .paymentRecovery: .recovery
        }
    }

    static func forWorkTask(_ taskID: String?) -> Self {
        switch taskID {
        case "hisobot", "soliq_izoh", "ish_haqi_vedomost": .accountingReport
        case "tijorat_taklifi": .commercialOffer
        case "xizmat_shartnomasi", "dalolatnoma": .contractDraft
        case "biznes_reja": .businessPlan
        case "hisob_faktura": .invoiceExport
        case "dars_rejasi": .lessonPlan
        case "test_tuzish", "ota_onaga_hisobot": .teacherFirstValue
        default: .officeFirstValue
        }
    }

    static var onboardingPersona: Self {
        switch PersonaStore.role {
        case "student": .studentFirstValue
        case "teacher": .teacherFirstValue
        case "business", "entrepreneur": .businessFirstValue
        case "accountant", "finance": .accountingReport
        case "employee", "office", "jobseeker": .officeFirstValue
        case "freelancer", "creator": .imageGenerationLimit
        case "developer", "it": .smartModelUpgrade
        default: .general
        }
    }

    var spec: PaywallContextSpec {
        switch self {
        case .general:
            .init(self, "/paywalls/salom-ai-toolkit-v1.webp", "AI vositalari — bir joyda", "Ish • o‘qish • ijod", "Davom etish", .monthly, "standard")
        case .presentationExport:
            .init(self, "/paywalls/presentation-result-v1.webp", "Taqdimot tayyor", "PPTX + PDF", "Yuklab olish", .monthly, "standard")
        case .referatExport:
            .init(self, "/paywalls/document-result-v1.webp", "Hujjat tayyor", "Word + PDF", "Yuklab olish", .monthly, "standard")
        case .accountingReport:
            .init(self, "/blog-images/ai-bilan-buxgalteriya-hisoboti-namuna.webp", "Hisobot — 4 daqiqada", "45 daqiqa → 4 daqiqa", "Hisobot yaratish", .yearly, "pro")
        case .commercialOffer:
            .init(self, "/blog-images/kommercheskiy-taklif-namuna.webp", "Taklif tayyor", "Professional format", "Taklif yaratish", .yearly, "pro")
        case .contractDraft:
            .init(self, "/blog-images/ai-bilan-shartnoma-drafti-tayyorlash.webp", "Shartnoma tayyor", "Bandlar • tomonlar • tekshiruv", "Draft yaratish", .yearly, "pro")
        case .businessPlan:
            .init(self, "/blog-images/ai-bilan-biznes-reja.webp", "Biznes reja tayyor", "Bozor → moliya → reja", "Reja yaratish", .yearly, "pro")
        case .invoiceExport:
            .init(self, "/blog-images/hisob-faktura-namuna.webp", "Hisob-faktura tayyor", "Yuborishga tayyor", "Hisob-faktura yaratish", .yearly, "standard")
        case .lessonPlan:
            .init(self, "/blog-images/ai-bilan-dars-rejasi-namuna.webp", "Dars rejasi tayyor", "Maqsad → faoliyat → baholash", "Reja yaratish", .monthly, "standard")
        case .dtmDailyLimit:
            .init(self, "/paywalls/dtm-progress-v1.webp", "Mashqni davom ettiring", "Yana savollar • xatolar tahlili", "Davom ettirish", .monthly, "standard")
        case .dtmScorePlan:
            .init(self, "/paywalls/dtm-progress-v1.webp", "O‘sish rejangiz", "Zaif mavzu → kunlik mashq", "Rejani ochish", .monthly, "standard")
        case .imageReferenceEdit:
            .init(self, "/paywalls/image-combine-v1.webp", "Rasmlarni birlashtiring", "Bir nechta rasm → yangi natija", "Tahrirlash", .monthly, "pro")
        case .imageGenerationLimit:
            .init(self, "/apps/image.webp", "Yana variantlar", "Ko‘proq rasm • yuqori sifat", "Davom ettirish", .monthly, "pro")
        case .voiceSessionLimit:
            .init(self, "/apps/voice.webp", "Suhbatni davom ettiring", "Ko‘proq ovozli daqiqa", "Davom ettirish", .monthly, "pro")
        case .fileAnalysisLimit:
            .init(self, "/blog-images/ai-bilan-pdf.webp", "Fayl tahlili", "PDF • Word • jadval", "Tahlilni ochish", .monthly, "pro")
        case .smartModelUpgrade:
            .init(self, "/blog-images/chatgpt-4-vs-5.webp", "Kuchliroq AI", "Chuqurroq tahlil", "Modelni ochish", .monthly, "pro")
        case .studentFirstValue:
            .init(self, "/blog-images/ai-bilan-imtihon.webp", "Talaba AI to‘plami", "DTM • referat • taqdimot", "To‘plamni ochish", .monthly, "standard")
        case .teacherFirstValue:
            .init(self, "/blog-images/ai-bilan-dars-tayyorlash.webp", "O‘qituvchi AI to‘plami", "Reja • test • material", "To‘plamni ochish", .monthly, "standard")
        case .businessFirstValue:
            .init(self, "/blog-images/ai-bilan-biznes-reja.webp", "Biznes AI tizimi", "Taklif • hisobot • reja", "Biznes rejasini tanlash", .yearly, "pro")
        case .officeFirstValue:
            .init(self, "/apps/work.webp", "Ish AI to‘plami", "Xat • bayonnoma • hisobot", "To‘plamni ochish", .yearly, "pro")
        case .paymentRecovery:
            .init(self, "/apps/work.webp", "Ishingiz saqlangan", "Hech narsani qayta boshlamang", "Taklifni ko‘rish", .monthly, "standard")
        }
    }
}

enum PaywallArtStyle: Equatable {
    case toolkit
    case presentation
    case document
    case beforeAfter
    case proposal
    case secureDocument
    case roadmap
    case invoice
    case lesson
    case quota
    case score
    case imageCompare
    case gallery
    case voice
    case fileAnalysis
    case modelCompare
    case student
    case teacher
    case business
    case office
    case recovery
}

struct PaywallContextSpec {
    let id: PaywallContextID
    let imagePath: String
    let titleUz: String
    let proofUz: String
    let ctaUz: String
    let defaultPeriod: BillingPeriod
    let recommendedTier: String

    init(_ id: PaywallContextID, _ imagePath: String, _ titleUz: String, _ proofUz: String, _ ctaUz: String, _ defaultPeriod: BillingPeriod, _ recommendedTier: String) {
        self.id = id
        self.imagePath = imagePath
        self.titleUz = titleUz
        self.proofUz = proofUz
        self.ctaUz = ctaUz
        self.defaultPeriod = defaultPeriod
        self.recommendedTier = recommendedTier
    }

    var imageURL: String {
#if DEBUG
        // Visual QA can point at the local web asset directory before the
        // production web deploy. Release builds always use the stable CDN URL.
        if let base = ProcessInfo.processInfo.environment["SALOM_PAYWALL_ASSET_BASE_URL"]?
            .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
           !base.isEmpty {
            return "\(base)\(imagePath)"
        }
#endif
        return "https://salom-ai.uz\(imagePath)"
    }
    var title: String { id.localizedCopy.title }
    var proof: String { id.localizedCopy.proof }
    var cta: String { id.localizedCopy.cta }
}

private struct PaywallCopySet {
    let uz: (String, String, String)
    let ru: (String, String, String)
    let en: (String, String, String)

    private var selected: (String, String, String) {
        let language = UserDefaults.standard.string(forKey: AppStorageKeys.preferredLanguageCode) ?? "uz"
        switch language {
        case "ru": return ru
        case "en": return en
        case "kr", "uz-Cyrl": return (UzCyrillic.toCyrillic(uz.0), UzCyrillic.toCyrillic(uz.1), UzCyrillic.toCyrillic(uz.2))
        default: return uz
        }
    }

    var title: String { selected.0 }
    var proof: String { selected.1 }
    var cta: String { selected.2 }
}

private extension PaywallContextID {
    var localizedCopy: PaywallCopySet {
        switch self {
        case .general:
            .init(uz: ("AI vositalari — bir joyda", "Ish • o‘qish • ijod", "Davom etish"), ru: ("ИИ-инструменты — в одном месте", "Работа • учёба • творчество", "Продолжить"), en: ("AI tools — in one place", "Work • study • create", "Continue"))
        case .presentationExport:
            .init(uz: ("Taqdimot tayyor", "PPTX + PDF", "Yuklab olish"), ru: ("Презентация готова", "PPTX + PDF", "Скачать"), en: ("Presentation ready", "PPTX + PDF", "Download"))
        case .referatExport:
            .init(uz: ("Hujjat tayyor", "Word + PDF", "Yuklab olish"), ru: ("Документ готов", "Word + PDF", "Скачать"), en: ("Document ready", "Word + PDF", "Download"))
        case .accountingReport:
            .init(uz: ("Hisobot — 4 daqiqada", "45 daqiqa → 4 daqiqa", "Hisobot yaratish"), ru: ("Отчёт — за 4 минуты", "45 минут → 4 минуты", "Создать отчёт"), en: ("Report — in 4 minutes", "45 minutes → 4 minutes", "Create report"))
        case .commercialOffer:
            .init(uz: ("Taklif tayyor", "Professional format", "Taklif yaratish"), ru: ("Предложение готово", "Профессиональный формат", "Создать предложение"), en: ("Proposal ready", "Professional format", "Create proposal"))
        case .contractDraft:
            .init(uz: ("Shartnoma tayyor", "Bandlar • tomonlar • tekshiruv", "Draft yaratish"), ru: ("Договор готов", "Пункты • стороны • проверка", "Создать черновик"), en: ("Contract ready", "Terms • parties • review", "Create draft"))
        case .businessPlan:
            .init(uz: ("Biznes reja tayyor", "Bozor → moliya → reja", "Reja yaratish"), ru: ("Бизнес-план готов", "Рынок → финансы → план", "Создать план"), en: ("Business plan ready", "Market → finance → plan", "Create plan"))
        case .invoiceExport:
            .init(uz: ("Hisob-faktura tayyor", "Yuborishga tayyor", "Hisob-faktura yaratish"), ru: ("Счёт готов", "Готов к отправке", "Создать счёт"), en: ("Invoice ready", "Ready to send", "Create invoice"))
        case .lessonPlan:
            .init(uz: ("Dars rejasi tayyor", "Maqsad → faoliyat → baholash", "Reja yaratish"), ru: ("План урока готов", "Цель → активность → оценка", "Создать план"), en: ("Lesson plan ready", "Goal → activity → assessment", "Create plan"))
        case .dtmDailyLimit:
            .init(uz: ("Mashqni davom ettiring", "Yana savollar • xatolar tahlili", "Davom ettirish"), ru: ("Продолжайте практику", "Больше вопросов • разбор ошибок", "Продолжить"), en: ("Keep practicing", "More questions • mistake review", "Continue"))
        case .dtmScorePlan:
            .init(uz: ("O‘sish rejangiz", "Zaif mavzu → kunlik mashq", "Rejani ochish"), ru: ("Ваш план роста", "Слабая тема → ежедневная практика", "Открыть план"), en: ("Your growth plan", "Weak topic → daily practice", "Open plan"))
        case .imageReferenceEdit:
            .init(uz: ("Rasmlarni birlashtiring", "Bir nechta rasm → yangi natija", "Tahrirlash"), ru: ("Объединяйте изображения", "Несколько фото → новый результат", "Редактировать"), en: ("Combine images", "Multiple images → a new result", "Edit images"))
        case .imageGenerationLimit:
            .init(uz: ("Yana variantlar", "Ko‘proq rasm • yuqori sifat", "Davom ettirish"), ru: ("Больше вариантов", "Больше изображений • выше качество", "Продолжить"), en: ("More variations", "More images • higher quality", "Continue"))
        case .voiceSessionLimit:
            .init(uz: ("Suhbatni davom ettiring", "Ko‘proq ovozli daqiqa", "Davom ettirish"), ru: ("Продолжайте разговор", "Больше голосовых минут", "Продолжить"), en: ("Keep talking", "More voice minutes", "Continue"))
        case .fileAnalysisLimit:
            .init(uz: ("Fayl tahlili", "PDF • Word • jadval", "Tahlilni ochish"), ru: ("Анализ файлов", "PDF • Word • таблицы", "Открыть анализ"), en: ("File analysis", "PDF • Word • spreadsheets", "Unlock analysis"))
        case .smartModelUpgrade:
            .init(uz: ("Kuchliroq AI", "Chuqurroq tahlil", "Modelni ochish"), ru: ("Более мощный ИИ", "Более глубокий анализ", "Открыть модель"), en: ("Stronger AI", "Deeper reasoning", "Unlock model"))
        case .studentFirstValue:
            .init(uz: ("Talaba AI to‘plami", "DTM • referat • taqdimot", "To‘plamni ochish"), ru: ("ИИ-набор студента", "DTM • реферат • презентация", "Открыть набор"), en: ("Student AI kit", "DTM • papers • presentations", "Open toolkit"))
        case .teacherFirstValue:
            .init(uz: ("O‘qituvchi AI to‘plami", "Reja • test • material", "To‘plamni ochish"), ru: ("ИИ-набор учителя", "План • тест • материалы", "Открыть набор"), en: ("Teacher AI kit", "Plans • tests • materials", "Open toolkit"))
        case .businessFirstValue:
            .init(uz: ("Biznes AI tizimi", "Taklif • hisobot • reja", "Biznes rejasini tanlash"), ru: ("ИИ-система для бизнеса", "Предложения • отчёты • планы", "Выбрать бизнес-план"), en: ("Business AI system", "Proposals • reports • plans", "Choose business plan"))
        case .officeFirstValue:
            .init(uz: ("Ish AI to‘plami", "Xat • bayonnoma • hisobot", "To‘plamni ochish"), ru: ("Рабочий ИИ-набор", "Письма • протоколы • отчёты", "Открыть набор"), en: ("Work AI kit", "Letters • minutes • reports", "Open toolkit"))
        case .paymentRecovery:
            .init(uz: ("Ishingiz saqlangan", "Hech narsani qayta boshlamang", "Taklifni ko‘rish"), ru: ("Ваша работа сохранена", "Не начинайте заново", "Посмотреть предложение"), en: ("Your work is saved", "No need to start over", "View offer"))
        }
    }
}

/// Carries the last visible conversion surface into redirect and saved-card
/// requests without changing the public payment APIs used by older screens.
final class PaywallAttributionStore {
    static let shared = PaywallAttributionStore()
    private(set) var paywallID: String?
    private(set) var source: String?

    private init() {}

    func set(context: PaywallContextID, source: String) {
        paywallID = context.rawValue
        self.source = source
    }

    var requestFields: [String: Any] {
        var fields: [String: Any] = ["platform": "ios"]
        if let paywallID { fields["paywall_id"] = paywallID; fields["intent_id"] = paywallID }
        if let source { fields["source"] = source }
        return fields
    }
}

struct PaywallDeepLinkRequest: Identifiable {
    let id = UUID()
    let context: PaywallContextID
    let source: String
}

@MainActor
final class AppDeepLinkRouter: ObservableObject {
    static let shared = AppDeepLinkRouter()
    @Published var paywallRequest: PaywallDeepLinkRequest?
    @Published var sectionRequest: MainSection?

    private init() {}

    /// Supports contextual paywall links (`/start/:intent`) and direct product
    /// links (`/presentations`, `/referats`, `/dtm`, `/work`, `/apps`, `/chat`).
    /// Requests stay queued while authentication is visible and are consumed by
    /// the main shell after sign-in, so an OAuth round trip never loses intent.
    func open(_ url: URL) {
        let components = url.pathComponents.filter { $0 != "/" }
        var rawContext: String?

        if url.scheme == "salomai", ["start", "open"].contains(url.host ?? "") {
            rawContext = components.first
        } else if ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host?.contains("salom-ai.uz") == true,
                  let startIndex = components.firstIndex(of: "start"),
                  components.indices.contains(startIndex + 1) {
            rawContext = components[startIndex + 1]
        }

        if let rawContext, let context = PaywallContextID(rawValue: rawContext) {
            let querySource = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "source" })?.value
            paywallRequest = .init(context: context, source: querySource ?? "ios_deep_link")
            return
        }

        let route: String? = {
            if url.scheme == "salomai" {
                if ["open", "feature"].contains(url.host ?? "") { return components.first }
                return url.host
            }
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host?.contains("salom-ai.uz") == true else { return nil }
            return components.first
        }()

        guard let route else { return }
        switch route.lowercased() {
        case "chat", "images", "image", "rasm": sectionRequest = .chat
        case "apps", "ilovalar": sectionRequest = .apps
        case "work", "business", "hisobot", "reports": sectionRequest = .ish
        case "presentations", "presentation", "taqdimotlar": sectionRequest = .presentations
        case "referats", "referat", "essay": sectionRequest = .referats
        case "dtm", "tests": sectionRequest = .dtm
        case "voice", "realtime": sectionRequest = .realtime
        default: break
        }
    }
}
