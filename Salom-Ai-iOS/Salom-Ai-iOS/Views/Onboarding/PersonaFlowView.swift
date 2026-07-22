//
//  PersonaFlowView.swift
//  Salom-Ai-iOS
//
//  Onboarding persona questionnaire that runs AFTER the capability scenes.
//  role → a tailored "what Salom AI does for YOU" value screen (real Pexels
//  photo) → goals. Everything optional with a Skip. Premium glass (iOS-26
//  material) on the dark onboarding backdrop. Saved locally; synced to the
//  backend after login (PersonaStore). 4 languages, natural Uzbek.
//

import SwiftUI

// MARK: - Localization helper (uz Latin / uz Cyrillic / ru / en)

struct L4 { let uz: String; let kr: String; let ru: String; let en: String
    func t(_ code: String) -> String {
        switch code { case "kr", "uz-Cyrl": return kr; case "ru": return ru; case "en": return en; default: return uz }
    }
}

// MARK: - Model

struct PersonaRole: Identifiable {
    let id: String
    let emoji: String
    let accent: Color
    let title: L4
    let tagline: L4
    let photo: String          // real Pexels image (fetched via /images/stock)
    let values: [L4]           // 3 tailored value points shown on the value screen
}

private let PERSONA_ROLES: [PersonaRole] = [
    .init(id: "student", emoji: "🎓", accent: Color(red: 0.40, green: 0.47, blue: 0.98),
          title: .init(uz: "O‘quvchi / Talaba", kr: "Ўқувчи / Талаба", ru: "Ученик / Студент", en: "Student / Pupil"),
          tagline: .init(uz: "DTM, uy vazifasi, insholar", kr: "ДТМ, уй вазифаси, иншолар", ru: "ДТМ, домашка, эссе", en: "DTM, homework, essays"),
          photo: "https://images.pexels.com/photos/7092523/pexels-photo-7092523.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "DTM testlari — fanlar bo‘yicha mashq va tahlil", kr: "ДТМ тестлари — фанлар бўйича машқ", ru: "Тесты ДТМ по предметам", en: "DTM practice tests by subject"),
            .init(uz: "Referat, insho va uy vazifasiga yordam", kr: "Реферат, иншо ва уй вазифаси", ru: "Помощь с рефератами и эссе", en: "Help with referats & essays"),
            .init(uz: "Har qanday mavzuni sodda tilda tushuntirish", kr: "Ҳар қандай мавзуни содда тилда", ru: "Объяснение любой темы просто", en: "Any topic explained simply"),
          ]),
    .init(id: "teacher", emoji: "📚", accent: SalomTheme.Colors.signal,
          title: .init(uz: "O‘qituvchi", kr: "Ўқитувчи", ru: "Учитель", en: "Teacher"),
          tagline: .init(uz: "Dars rejasi, testlar, hisobotlar", kr: "Дарс режаси, тестлар, ҳисоботлар", ru: "Планы, тесты, отчёты", en: "Lesson plans, tests, reports"),
          photo: "https://images.pexels.com/photos/37795357/pexels-photo-37795357.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Dars rejalari — bir necha soniyada", kr: "Дарс режалари — тез", ru: "Планы уроков за секунды", en: "Lesson plans in seconds"),
            .init(uz: "Test va topshiriqlar tayyorlash", kr: "Тест ва топшириқлар", ru: "Тесты и задания", en: "Tests & assignments"),
            .init(uz: "Ota-onalarga hisobot va xatlar", kr: "Ота-оналарга ҳисобот", ru: "Отчёты родителям", en: "Parent reports & letters"),
          ]),
    .init(id: "business", emoji: "💼", accent: Color(red: 0.55, green: 0.42, blue: 0.98),
          title: .init(uz: "Tadbirkor", kr: "Тадбиркор", ru: "Предприниматель", en: "Business owner"),
          tagline: .init(uz: "Taklif, shartnoma, biznes-reja", kr: "Таклиф, шартнома, бизнес-режа", ru: "КП, договор, бизнес-план", en: "Proposals, contracts, plans"),
          photo: "https://images.pexels.com/photos/7693692/pexels-photo-7693692.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Tijorat taklifi va shartnomalar", kr: "Тижорат таклифи ва шартномалар", ru: "Коммерческие предложения и договоры", en: "Proposals & contracts"),
            .init(uz: "Biznes-reja va hisob-fakturalar", kr: "Бизнес-режа ва ҳисоб-фактура", ru: "Бизнес-планы и счета", en: "Business plans & invoices"),
            .init(uz: "Taqdimotlar — mijoz va investorlar uchun", kr: "Тақдимотлар — мижозлар учун", ru: "Презентации для клиентов", en: "Presentations for clients"),
          ]),
    .init(id: "accountant", emoji: "🧮", accent: Color(red: 0.10, green: 0.65, blue: 0.56),
          title: .init(uz: "Buxgalter / Moliyachi", kr: "Бухгалтер / Молиячи", ru: "Бухгалтер / Финансист", en: "Accountant / Finance"),
          tagline: .init(uz: "Hisobot, QQS, hisob-faktura", kr: "Ҳисобот, ҚҚС, ҳисоб-фактура", ru: "Отчёты, НДС, счета", en: "Reports, tax, invoices"),
          photo: "https://images.pexels.com/photos/32201000/pexels-photo-32201000.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Moliyaviy hisobot va tahlillar", kr: "Молиявий ҳисобот ва таҳлиллар", ru: "Финансовые отчёты и анализ", en: "Financial reports and analysis"),
            .init(uz: "Soliq/QQS izohlari, ish haqi vedomosti", kr: "Солиқ/ҚҚС, иш ҳақи ведомости", ru: "Налоги/НДС, зарплатные ведомости", en: "Tax/VAT notes, payroll"),
            .init(uz: "Hisob-faktura va dalolatnomalar", kr: "Ҳисоб-фактура ва далолатномалар", ru: "Счета и акты", en: "Invoices and acts"),
          ]),
    .init(id: "office", emoji: "🏢", accent: Color(red: 0.98, green: 0.62, blue: 0.15),
          title: .init(uz: "Ofis mutaxassisi", kr: "Офис мутахассиси", ru: "Офисный специалист", en: "Office professional"),
          tagline: .init(uz: "Xat, tahlil, taqdimot", kr: "Хат, таҳлил, тақдимот", ru: "Письма, анализ, презентации", en: "Letters, analysis, presentations"),
          photo: "https://images.pexels.com/photos/3184465/pexels-photo-3184465.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Rasmiy xatlar va hisobotlar", kr: "Расмий хатлар ва ҳисоботлар", ru: "Официальные письма и отчёты", en: "Official letters and reports"),
            .init(uz: "Uchrashuv xulosasi va tahlil", kr: "Учрашув хулосаси ва таҳлил", ru: "Итоги встреч и анализ", en: "Meeting summaries and analysis"),
            .init(uz: "Taqdimot va tarjimalar", kr: "Тақдимот ва таржималар", ru: "Презентации и переводы", en: "Presentations and translations"),
          ]),
    .init(id: "freelancer", emoji: "🎨", accent: Color(red: 0.91, green: 0.30, blue: 0.62),
          title: .init(uz: "Frilanser / Ijodkor", kr: "Фрилансер / Ижодкор", ru: "Фрилансер / Автор", en: "Freelancer / Creator"),
          tagline: .init(uz: "Kontent, rasm, mijozlar", kr: "Контент, расм, мижозлар", ru: "Контент, изображения, клиенты", en: "Content, images, clients"),
          photo: "https://images.pexels.com/photos/3861969/pexels-photo-3861969.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Kontent g‘oyalari va matnlar", kr: "Контент ғоялари ва матнлар", ru: "Идеи и тексты для контента", en: "Content ideas and copy"),
            .init(uz: "AI rasmlar va variantlar", kr: "AI расмлар ва вариантлар", ru: "ИИ-изображения и варианты", en: "AI images and variations"),
            .init(uz: "Mijoz uchun taklif va brief", kr: "Мижоз учун таклиф ва бриф", ru: "Предложения и брифы для клиентов", en: "Client proposals and briefs"),
          ]),
    .init(id: "developer", emoji: "💻", accent: Color(red: 0.15, green: 0.63, blue: 0.91),
          title: .init(uz: "Dasturchi / IT", kr: "Дастурчи / IT", ru: "Разработчик / IT", en: "Developer / IT"),
          tagline: .init(uz: "Kod, tahlil, hujjatlar", kr: "Код, таҳлил, ҳужжатлар", ru: "Код, анализ, документация", en: "Code, analysis, documentation"),
          photo: "https://images.pexels.com/photos/574071/pexels-photo-574071.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Kod yozish va xatoni topish", kr: "Код ёзиш ва хатони топиш", ru: "Написание и проверка кода", en: "Write and debug code"),
            .init(uz: "Texnik tahlil va hujjatlar", kr: "Техник таҳлил ва ҳужжатлар", ru: "Технический анализ и документация", en: "Technical analysis and docs"),
            .init(uz: "Murakkab mavzuni tez tushunish", kr: "Мураккаб мавзуни тез тушуниш", ru: "Быстро разбираться в сложном", en: "Understand complex topics faster"),
          ]),
    .init(id: "jobseeker", emoji: "🎯", accent: Color(red: 0.94, green: 0.45, blue: 0.20),
          title: .init(uz: "Ish izlayapman", kr: "Иш излаяпман", ru: "Ищу работу", en: "Looking for work"),
          tagline: .init(uz: "CV, suhbat, ingliz tili", kr: "CV, суҳбат, инглиз тили", ru: "Резюме, интервью, английский", en: "CV, interviews, English"),
          photo: "https://images.pexels.com/photos/4344860/pexels-photo-4344860.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Vakansiyaga mos CV va xat", kr: "Вакансияга мос CV ва хат", ru: "Резюме и письмо под вакансию", en: "Tailored CV and cover letter"),
            .init(uz: "Suhbat savollariga tayyorgarlik", kr: "Суҳбат саволларига тайёргарлик", ru: "Подготовка к интервью", en: "Interview preparation"),
            .init(uz: "Inglizcha javoblarni mashq qilish", kr: "Инглизча жавобларни машқ қилиш", ru: "Практика ответов на английском", en: "Practice answers in English"),
          ]),
    .init(id: "personal", emoji: "✨", accent: Color(red: 0.47, green: 0.38, blue: 0.95),
          title: .init(uz: "Shaxsiy foydalanish", kr: "Шахсий фойдаланиш", ru: "Для себя", en: "Personal use"),
          tagline: .init(uz: "Savol, tarjima, rasm, ovoz", kr: "Савол, таржима, расм, овоз", ru: "Вопросы, перевод, изображения, голос", en: "Questions, translation, images, voice"),
          photo: "https://images.pexels.com/photos/3769021/pexels-photo-3769021.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Kundalik savollarga tez javob", kr: "Кундалик саволларга тез жавоб", ru: "Быстрые ответы на каждый день", en: "Fast everyday answers"),
            .init(uz: "Tarjima, matn va rasm", kr: "Таржима, матн ва расм", ru: "Перевод, тексты и изображения", en: "Translation, writing and images"),
            .init(uz: "Ovozli suhbat va yordam", kr: "Овозли суҳбат ва ёрдам", ru: "Голосовой разговор и помощь", en: "Voice conversation and help"),
          ]),
]

struct PersonaGoal: Identifiable { let id: String; let emoji: String; let label: L4 }

private let PERSONA_GOALS: [PersonaGoal] = [
    .init(id: "dtm", emoji: "🎓", label: .init(uz: "DTM tayyorgarlik", kr: "ДТМ тайёргарлик", ru: "Подготовка к ДТМ", en: "DTM prep")),
    .init(id: "presentations", emoji: "📊", label: .init(uz: "Taqdimot yasash", kr: "Тақдимот ясаш", ru: "Презентации", en: "Presentations")),
    .init(id: "referat", emoji: "📝", label: .init(uz: "Referat / insho", kr: "Реферат / иншо", ru: "Рефераты / эссе", en: "Referats / essays")),
    .init(id: "work_docs", emoji: "💼", label: .init(uz: "Ish hujjatlari", kr: "Иш ҳужжатлари", ru: "Рабочие документы", en: "Work documents")),
    .init(id: "accounting", emoji: "🧮", label: .init(uz: "Hisobot va soliqlar", kr: "Ҳисобот ва солиқлар", ru: "Отчёты и налоги", en: "Reports and tax")),
    .init(id: "coding", emoji: "💻", label: .init(uz: "Kod va IT", kr: "Код ва IT", ru: "Код и IT", en: "Code and IT")),
    .init(id: "cv", emoji: "🎯", label: .init(uz: "CV va suhbat", kr: "CV ва суҳбат", ru: "Резюме и интервью", en: "CV and interviews")),
    .init(id: "images", emoji: "🖼️", label: .init(uz: "Rasm yaratish", kr: "Расм яратиш", ru: "Генерация картинок", en: "Image generation")),
    .init(id: "english", emoji: "🇬🇧", label: .init(uz: "Ingliz tili", kr: "Инглиз тили", ru: "Английский язык", en: "English")),
    .init(id: "translate", emoji: "🌐", label: .init(uz: "Tarjima", kr: "Таржима", ru: "Перевод", en: "Translation")),
    .init(id: "daily", emoji: "💡", label: .init(uz: "Kundalik yordam", kr: "Кундалик ёрдам", ru: "Ежедневная помощь", en: "Everyday help")),
]

// MARK: - Flow

struct PersonaFlowView: View {
    /// Called with the chosen role id (nil if skipped) + selected goal ids.
    let onComplete: (String?, [String]) -> Void

    @AppStorage(AppStorageKeys.preferredLanguageCode) private var lang: String = "uz"
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Step] = []
    @State private var role: PersonaRole?
    @State private var goals: Set<String> = []

    // The destination carries the role id in the path VALUE — not external
    // @State — so the pushed screen never reads a stale/nil role on first push
    // (that caused a blank screen the first time).
    private enum Step: Hashable { case value(String), goals(String) }
    private var defaultAccent: Color { Color(red: 0.30, green: 0.55, blue: 0.98) }

    private func roleFor(_ id: String) -> PersonaRole {
        PERSONA_ROLES.first { $0.id == id } ?? PERSONA_ROLES[0]
    }

    private func goalIDs(for roleID: String) -> Set<String> {
        switch roleID {
        case "student": return Set(["dtm", "presentations", "referat", "english"])
        case "teacher": return Set(["presentations", "work_docs", "images", "daily"])
        case "business": return Set(["presentations", "work_docs", "images", "translate"])
        case "accountant": return Set(["accounting", "work_docs", "translate", "daily"])
        case "office": return Set(["work_docs", "presentations", "translate", "daily"])
        case "freelancer": return Set(["images", "presentations", "work_docs", "translate"])
        case "developer": return Set(["coding", "work_docs", "english", "translate"])
        case "jobseeker": return Set(["cv", "english", "translate", "work_docs"])
        default: return Set(["daily", "translate", "images", "english"])
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            roleStep
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .value(let id): valueStep(roleFor(id))
                    case .goals(let id): goalsStep(roleFor(id))
                    }
                }
        }
        .tint(SalomTheme.Colors.accentPrimary)
    }

    // Adaptive onboarding backdrop with an accent glow (accent follows the role).
    private func backdrop(_ accent: Color) -> some View {
        ZStack {
            SalomTheme.Colors.bgMain
            Circle().fill(accent.opacity(0.20)).frame(width: 340, height: 340).blur(radius: 100).offset(x: -110, y: -230)
            Circle().fill(accent.opacity(0.14)).frame(width: 320, height: 320).blur(radius: 100).offset(x: 120, y: 260)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: accent)
    }

    // Progress dots for the toolbar's principal slot.
    private func dots(_ current: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule().fill(i == current ? SalomTheme.Colors.textPrimary : SalomTheme.Colors.textTertiary.opacity(0.35))
                    .frame(width: i == current ? 20 : 6, height: 6)
            }
        }
    }

    private var skipButton: some View {
        Button { onComplete(role?.id, Array(goals)) } label: {
            Text(L4(uz: "O‘tkazish", kr: "Ўтказиш", ru: "Пропустить", en: "Skip").t(lang))
                .font(.system(size: 15, weight: .regular)).foregroundColor(SalomTheme.Colors.textSecondary)
        }
    }

    // MARK: Step 0 — role (NavigationStack root)
    private var roleStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L4(uz: "Sizni yaxshiroq tanishimiz uchun", kr: "Сизни яхшироқ танишимиз учун",
                    ru: "Чтобы узнать вас лучше", en: "So we get to know you").t(lang))
                .font(.system(size: 24, weight: .bold)).foregroundColor(SalomTheme.Colors.textPrimary)
            Text(L4(uz: "Kimsiz? Javobingizga qarab eng foydali vositalarni ko‘rsatamiz.",
                    kr: "Кимсиз? Жавобингизга қараб фойдали воситаларни кўрсатамиз.",
                    ru: "Кто вы? Покажем самые полезные инструменты.",
                    en: "Who are you? We'll show the most useful tools.").t(lang))
                .font(.system(size: 14)).foregroundColor(SalomTheme.Colors.textSecondary)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(PERSONA_ROLES) { r in
                        Button {
                            HapticManager.shared.fire(.selection)
                            role = r
                            path.append(.value(r.id))   // native push → native slide + back
                        } label: { roleCard(r) }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 18).padding(.bottom, 30)
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backdrop(defaultAccent))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left") }
            }
            ToolbarItem(placement: .principal) { dots(0) }
            ToolbarItem(placement: .topBarTrailing) { skipButton }
        }
    }

    private func roleCard(_ r: PersonaRole) -> some View {
        HStack(spacing: 14) {
            Text(r.emoji).font(.system(size: 30))
                .frame(width: 54, height: 54)
                .background(r.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(r.title.t(lang)).font(.system(size: 16, weight: .semibold)).foregroundColor(SalomTheme.Colors.textPrimary)
                Text(r.tagline.t(lang)).font(.system(size: 12.5)).foregroundColor(SalomTheme.Colors.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(SalomTheme.Colors.textTertiary)
        }
        .padding(14)
        .background(SalomTheme.Colors.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(LinearGradient(colors: [r.accent.opacity(0.5), SalomTheme.Colors.border], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }

    // MARK: Step 1 — tailored value (real photo)
    private func valueStep(_ r: PersonaRole) -> some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Real Pexels photo with a shimmer placeholder + gradient scrim.
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: URL(string: r.photo)) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            case .empty: ShimmerView()
                            case .failure: Rectangle().fill(r.accent.opacity(0.25))
                            @unknown default: Rectangle().fill(r.accent.opacity(0.25))
                            }
                        }
                        .frame(height: 200).frame(maxWidth: .infinity).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                        HStack(spacing: 8) {
                            Text(r.emoji).font(.system(size: 24))
                            Text(r.title.t(lang)).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        }.padding(16)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SalomTheme.Colors.border))

                    Text(L4(uz: "Ajoyib! Salom AI siz uchun:", kr: "Ажойиб! Салом AI сиз учун:",
                            ru: "Отлично! Salom AI для вас:", en: "Great! Salom AI for you:").t(lang))
                        .font(.system(size: 20, weight: .bold)).foregroundColor(SalomTheme.Colors.textPrimary)

                    VStack(spacing: 10) {
                        ForEach(Array(r.values.enumerated()), id: \.offset) { _, v in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(r.accent)
                                Text(v.t(lang)).font(.system(size: 14.5, weight: .medium)).foregroundColor(SalomTheme.Colors.textPrimary)
                                Spacer(minLength: 0)
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SalomTheme.Colors.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 24)
            }
            primaryButton(L4(uz: "Davom etish", kr: "Давом этиш", ru: "Продолжить", en: "Continue").t(lang)) {
                path.append(.goals(r.id))
            }
        }
        .background(backdrop(r.accent))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { dots(1) }
            ToolbarItem(placement: .topBarTrailing) { skipButton }
        }
    }

    // MARK: Step 2 — goals
    private func goalsStep(_ r: PersonaRole) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L4(uz: "Nima bilan boshlaymiz?", kr: "Нима билан бошлаймиз?", ru: "С чего начнём?", en: "Where shall we start?").t(lang))
                .font(.system(size: 24, weight: .bold)).foregroundColor(SalomTheme.Colors.textPrimary)
            Text(L4(uz: "Bir nechtasini tanlang (ixtiyoriy).", kr: "Бир нечтасини танланг (ихтиёрий).",
                    ru: "Выберите несколько (необязательно).", en: "Pick a few (optional).").t(lang))
                .font(.system(size: 14)).foregroundColor(SalomTheme.Colors.textSecondary)

            ScrollView(showsIndicators: false) {
                FlowChips(goals: $goals, lang: lang, allowedIDs: goalIDs(for: r.id))
                    .padding(.top, 18).padding(.bottom, 24)
            }
            primaryButton(L4(uz: "Tayyor", kr: "Тайёр", ru: "Готово", en: "Done").t(lang)) {
                HapticManager.shared.fire(.success)
                onComplete(r.id, Array(goals))
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backdrop(r.accent))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { dots(2) }
            ToolbarItem(placement: .topBarTrailing) { skipButton }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title); Image(systemName: "arrow.right") }
                .font(.system(size: 16, weight: .semibold)).foregroundColor(SalomTheme.Colors.onAccent)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background((role?.accent ?? Color(red: 0.30, green: 0.55, blue: 0.98)))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal, 22).padding(.bottom, 40)
    }
}

/// Reusable skeleton shimmer for image loading (AsyncImage `.empty` phase).
struct ShimmerView: View {
    @State private var move = false
    var body: some View {
        Rectangle()
            .fill(SalomTheme.Colors.surfaceMuted)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, SalomTheme.Colors.textPrimary.opacity(0.12), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: move ? geo.size.width * 1.1 : -geo.size.width * 0.6)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) { move = true }
            }
    }
}

// Wrapping chip layout for goals.
private struct FlowChips: View {
    @Binding var goals: Set<String>
    let lang: String
    let allowedIDs: Set<String>

    var body: some View {
        // Simple 2-column grid keeps it robust across iOS versions.
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(PERSONA_GOALS.filter { allowedIDs.contains($0.id) }) { g in
                let on = goals.contains(g.id)
                Button {
                    HapticManager.shared.fire(.selection)
                    if on { goals.remove(g.id) } else { goals.insert(g.id) }
                } label: {
                    HStack(spacing: 8) {
                        Text(g.emoji).font(.system(size: 18))
                        Text(g.label.t(lang)).font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(SalomTheme.Colors.textPrimary).lineLimit(1).minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                        if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(SalomTheme.Colors.accentPrimary) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SalomTheme.Colors.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(on ? SalomTheme.Colors.accentPrimary.opacity(0.7) : SalomTheme.Colors.border, lineWidth: on ? 1.5 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
