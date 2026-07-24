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
    case documentExplainerPro = "document_explainer_pro"
    case governmentGuidePro = "government_guide_pro"
    case taxPlannerPro = "tax_planner_pro"
    case salaryPlannerPro = "salary_planner_pro"
    case vehicleAssistantPro = "vehicle_assistant_pro"
    case moneyPlannerPro = "money_planner_pro"
    case jobAssistantPro = "job_assistant_pro"
    case migrantHelperPro = "migrant_helper_pro"
    case familyBenefitsPro = "family_benefits_pro"
    case teacherAssistantPro = "teacher_assistant_pro"
    case utilitiesHelperPro = "utilities_helper_pro"
    case marketplaceSellerPro = "marketplace_seller_pro"
    case voiceNotesPro = "voice_notes_pro"
    case farmerAssistantPro = "farmer_assistant_pro"
    case healthVisitPro = "health_visit_pro"

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
        case .documentExplainerPro: .fileAnalysis
        case .governmentGuidePro: .secureDocument
        case .taxPlannerPro: .beforeAfter
        case .salaryPlannerPro: .score
        case .vehicleAssistantPro: .roadmap
        case .moneyPlannerPro: .score
        case .jobAssistantPro: .beforeAfter
        case .migrantHelperPro: .roadmap
        case .familyBenefitsPro: .secureDocument
        case .teacherAssistantPro: .lesson
        case .utilitiesHelperPro: .beforeAfter
        case .marketplaceSellerPro: .gallery
        case .voiceNotesPro: .voice
        case .farmerAssistantPro: .roadmap
        case .healthVisitPro: .secureDocument
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
        case .documentExplainerPro:
            .init(self, "/mini-app-assets/document-explainer.webp", "Hujjatdagi muhim joyni toping", "Bandlar • muddatlar • xavflar", "Hujjatni tahlil qilish", .monthly, "pro")
        case .governmentGuidePro:
            .init(self, "/mini-app-assets/government-guide.webp", "To‘g‘ri xizmatga boring", "Rasmiy manba • aniq qadam", "Yo‘riqchini ochish", .monthly, "standard")
        case .taxPlannerPro:
            .init(self, "/mini-app-assets/tax-self-employed.webp", "Soliq yo‘lingizni aniqlang", "Maqom • tushum • rasmiy qadam", "Hisobni boshlash", .yearly, "pro")
        case .salaryPlannerPro:
            .init(self, "/mini-app-assets/salary-employment.webp", "Maoshingizni tushuning", "Brutto → netto → hujjatlar", "Hisobni ochish", .monthly, "standard")
        case .vehicleAssistantPro:
            .init(self, "/mini-app-assets/vehicle-assistant.webp", "Safarni oldindan hisoblang", "Yoqilg‘i • xizmat • ishonchnoma", "Avto yordamchini ochish", .yearly, "pro")
        case .moneyPlannerPro:
            .init(self, "/mini-app-assets/money-planner.webp", "Pul qayerga ketayotganini ko‘ring", "Daromad → xarajat → jamg‘arma", "Byudjetni tuzish", .monthly, "standard")
        case .jobAssistantPro:
            .init(self, "/mini-app-assets/job-assistant.webp", "Vakansiyaga mos CV", "CV • xat • suhbat", "Ish to‘plamini ochish", .monthly, "pro")
        case .migrantHelperPro:
            .init(self, "/mini-app-assets/migrant-helper.webp", "Safarga xavfsiz tayyorlaning", "Hujjat • muddat • rasmiy manba", "Ro‘yxatni olish", .monthly, "standard")
        case .familyBenefitsPro:
            .init(self, "/mini-app-assets/family-benefits.webp", "Oilaga mos yordamni toping", "Nafaqa • bog‘cha • hujjatlar", "Yo‘riqchini ochish", .monthly, "standard")
        case .teacherAssistantPro:
            .init(self, "/mini-app-assets/teacher-assistant.webp", "Darsni tezroq tayyorlang", "Reja • test • baholash", "O‘qituvchi to‘plamini ochish", .yearly, "pro")
        case .utilitiesHelperPro:
            .init(self, "/mini-app-assets/utilities-helper.webp", "Kvitansiyani tushuning", "Hisob • izoh • murojaat", "Yordamchini ochish", .monthly, "standard")
        case .marketplaceSellerPro:
            .init(self, "/mini-app-assets/marketplace-seller.webp", "Mahsulotni yaxshiroq soting", "Kartochka • narx • javoblar", "Sotuvchi to‘plamini ochish", .yearly, "pro")
        case .voiceNotesPro:
            .init(self, "/mini-app-assets/voice-notes.webp", "Gapiring — natija tayyor", "Xulosa • vazifa • qaror", "Ovozli vositani ochish", .monthly, "pro")
        case .farmerAssistantPro:
            .init(self, "/mini-app-assets/farmer-assistant.webp", "Mavsumni aniq rejalang", "Ekin • xarajat • ish jadvali", "Dehqon rejasini ochish", .yearly, "pro")
        case .healthVisitPro:
            .init(self, "/mini-app-assets/health-visit.webp", "Qabulga tayyor boring", "Alomat • dori • savollar", "Qabul varag‘ini ochish", .monthly, "standard")
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
        case .documentExplainerPro:
            .init(uz: ("Hujjatdagi muhim joyni toping", "Bandlar • muddatlar • xavflar", "Hujjatni tahlil qilish"), ru: ("Найдите главное в документе", "Пункты • сроки • риски", "Разобрать документ"), en: ("Find what matters in a document", "Clauses • dates • risks", "Analyze document"))
        case .governmentGuidePro:
            .init(uz: ("To‘g‘ri xizmatga boring", "Rasmiy manba • aniq qadam", "Yo‘riqchini ochish"), ru: ("Перейдите к нужной услуге", "Официально • пошагово", "Открыть навигатор"), en: ("Reach the right service", "Official • step by step", "Open guide"))
        case .taxPlannerPro:
            .init(uz: ("Soliq yo‘lingizni aniqlang", "Maqom • tushum • rasmiy qadam", "Hisobni boshlash"), ru: ("Разберитесь с налогами", "Статус • доход • шаги", "Начать расчёт"), en: ("Clarify your tax path", "Status • revenue • official steps", "Start calculation"))
        case .salaryPlannerPro:
            .init(uz: ("Maoshingizni tushuning", "Brutto → netto → hujjatlar", "Hisobni ochish"), ru: ("Разберитесь в зарплате", "Брутто → нетто → справки", "Открыть расчёт"), en: ("Understand your salary", "Gross → net → certificates", "Open calculator"))
        case .vehicleAssistantPro:
            .init(uz: ("Safarni oldindan hisoblang", "Yoqilg‘i • xizmat • ishonchnoma", "Avto yordamchini ochish"), ru: ("Рассчитайте поездку заранее", "Топливо • услуги • доверенность", "Открыть автопомощник"), en: ("Plan the trip before you go", "Fuel • services • authorization", "Open vehicle assistant"))
        case .moneyPlannerPro:
            .init(uz: ("Pul qayerga ketayotganini ko‘ring", "Daromad → xarajat → jamg‘arma", "Byudjetni tuzish"), ru: ("Узнайте, куда уходят деньги", "Доход → расходы → накопления", "Составить бюджет"), en: ("See where your money goes", "Income → expenses → savings", "Build budget"))
        case .jobAssistantPro:
            .init(uz: ("Vakansiyaga mos CV", "CV • xat • suhbat", "Ish to‘plamini ochish"), ru: ("Резюме под вакансию", "Резюме • письмо • интервью", "Открыть набор"), en: ("A CV tailored to the role", "CV • letter • interview", "Open job toolkit"))
        case .migrantHelperPro:
            .init(uz: ("Safarga xavfsiz tayyorlaning", "Hujjat • muddat • rasmiy manba", "Ro‘yxatni olish"), ru: ("Подготовьтесь к поездке безопасно", "Документы • сроки • официально", "Получить список"), en: ("Prepare to travel safely", "Documents • timing • official sources", "Get checklist"))
        case .familyBenefitsPro:
            .init(uz: ("Oilaga mos yordamni toping", "Nafaqa • bog‘cha • hujjatlar", "Yo‘riqchini ochish"), ru: ("Найдите помощь для семьи", "Пособия • сад • документы", "Открыть навигатор"), en: ("Find support for your family", "Benefits • kindergarten • documents", "Open guide"))
        case .teacherAssistantPro:
            .init(uz: ("Darsni tezroq tayyorlang", "Reja • test • baholash", "O‘qituvchi to‘plamini ochish"), ru: ("Готовьте уроки быстрее", "План • тест • оценивание", "Открыть набор учителя"), en: ("Prepare lessons faster", "Plan • quiz • assessment", "Open teacher toolkit"))
        case .utilitiesHelperPro:
            .init(uz: ("Kvitansiyani tushuning", "Hisob • izoh • murojaat", "Yordamchini ochish"), ru: ("Разберитесь в квитанции", "Расчёт • объяснение • обращение", "Открыть помощник"), en: ("Understand your utility bill", "Charges • explanation • request", "Open helper"))
        case .marketplaceSellerPro:
            .init(uz: ("Mahsulotni yaxshiroq soting", "Kartochka • narx • javoblar", "Sotuvchi to‘plamini ochish"), ru: ("Продавайте товар лучше", "Карточка • цена • ответы", "Открыть набор продавца"), en: ("Sell your product better", "Listing • price • replies", "Open seller toolkit"))
        case .voiceNotesPro:
            .init(uz: ("Gapiring — natija tayyor", "Xulosa • vazifa • qaror", "Ovozli vositani ochish"), ru: ("Говорите — результат готов", "Итог • задачи • решения", "Открыть голосовой инструмент"), en: ("Speak—get a result", "Summary • tasks • decisions", "Open voice tool"))
        case .farmerAssistantPro:
            .init(uz: ("Mavsumni aniq rejalang", "Ekin • xarajat • ish jadvali", "Dehqon rejasini ochish"), ru: ("Планируйте сезон точнее", "Культура • затраты • график", "Открыть план"), en: ("Plan the season clearly", "Crop • costs • work schedule", "Open farm plan"))
        case .healthVisitPro:
            .init(uz: ("Qabulga tayyor boring", "Alomat • dori • savollar", "Qabul varag‘ini ochish"), ru: ("Подготовьтесь к приёму", "Симптомы • лекарства • вопросы", "Открыть лист приёма"), en: ("Arrive prepared for your visit", "Symptoms • medicines • questions", "Open visit sheet"))
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
    @Published var miniAppRequest: String?

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
        case "apps", "ilovalar":
            sectionRequest = .apps
            if components.count > 1 { miniAppRequest = components[1] }
        case "work", "business", "hisobot", "reports": sectionRequest = .ish
        case "presentations", "presentation", "taqdimotlar": sectionRequest = .presentations
        case "referats", "referat", "essay": sectionRequest = .referats
        case "dtm", "tests": sectionRequest = .dtm
        case "voice", "realtime": sectionRequest = .realtime
        default: break
        }
    }
}
