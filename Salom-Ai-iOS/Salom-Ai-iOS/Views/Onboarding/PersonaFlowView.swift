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
        switch code { case "kr": return kr; case "ru": return ru; case "en": return en; default: return uz }
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
    .init(id: "teacher", emoji: "📚", accent: Color(red: 0.13, green: 0.70, blue: 0.53),
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
    .init(id: "office", emoji: "🏢", accent: Color(red: 0.98, green: 0.62, blue: 0.15),
          title: .init(uz: "Ofis / Buxgalter / Yurist", kr: "Офис / Бухгалтер / Юрист", ru: "Офис / Бухгалтер / Юрист", en: "Office / Accountant / Lawyer"),
          tagline: .init(uz: "Hisobot, rasmiy xat, QQS", kr: "Ҳисобот, расмий хат, ҚҚС", ru: "Отчёты, письма, НДС", en: "Reports, letters, tax"),
          photo: "https://images.pexels.com/photos/32201000/pexels-photo-32201000.jpeg?auto=compress&cs=tinysrgb&w=1000",
          values: [
            .init(uz: "Rasmiy xatlar va hisobotlar", kr: "Расмий хатлар ва ҳисоботлар", ru: "Официальные письма и отчёты", en: "Official letters & reports"),
            .init(uz: "Soliq/QQS izohlari, ish haqi vedomosti", kr: "Солиқ/ҚҚС, иш ҳақи ведомости", ru: "Налоги/НДС, зарплатные ведомости", en: "Tax/VAT notes, payroll"),
            .init(uz: "Shartnoma va dalolatnomalar", kr: "Шартнома ва далолатномалар", ru: "Договоры и акты", en: "Contracts & acts"),
          ]),
]

struct PersonaGoal: Identifiable { let id: String; let emoji: String; let label: L4 }

private let PERSONA_GOALS: [PersonaGoal] = [
    .init(id: "dtm", emoji: "🎓", label: .init(uz: "DTM tayyorgarlik", kr: "ДТМ тайёргарлик", ru: "Подготовка к ДТМ", en: "DTM prep")),
    .init(id: "presentations", emoji: "📊", label: .init(uz: "Taqdimot yasash", kr: "Тақдимот ясаш", ru: "Презентации", en: "Presentations")),
    .init(id: "referat", emoji: "📝", label: .init(uz: "Referat / insho", kr: "Реферат / иншо", ru: "Рефераты / эссе", en: "Referats / essays")),
    .init(id: "work_docs", emoji: "💼", label: .init(uz: "Ish hujjatlari", kr: "Иш ҳужжатлари", ru: "Рабочие документы", en: "Work documents")),
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

    private enum Step: Hashable { case value, goals }
    private var defaultAccent: Color { Color(red: 0.30, green: 0.55, blue: 0.98) }

    var body: some View {
        NavigationStack(path: $path) {
            roleStep
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .value: valueStep
                    case .goals: goalsStep
                    }
                }
        }
        .tint(.white)   // native back chevron + toolbar buttons in white
    }

    // Dark onboarding backdrop with an accent glow (accent follows the role).
    private func backdrop(_ accent: Color) -> some View {
        ZStack {
            Color(red: 0.008, green: 0.024, blue: 0.09)
            Circle().fill(accent.opacity(0.28)).frame(width: 340, height: 340).blur(radius: 100).offset(x: -110, y: -230)
            Circle().fill(accent.opacity(0.20)).frame(width: 320, height: 320).blur(radius: 100).offset(x: 120, y: 260)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: accent)
    }

    // Progress dots for the toolbar's principal slot.
    private func dots(_ current: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule().fill(i == current ? Color.white : Color.white.opacity(0.25))
                    .frame(width: i == current ? 20 : 6, height: 6)
            }
        }
    }

    private var skipButton: some View {
        Button { onComplete(role?.id, Array(goals)) } label: {
            Text(L4(uz: "O‘tkazish", kr: "Ўтказиш", ru: "Пропустить", en: "Skip").t(lang))
                .font(.system(size: 15, weight: .regular)).foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: Step 0 — role (NavigationStack root)
    private var roleStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L4(uz: "Sizni yaxshiroq tanishimiz uchun", kr: "Сизни яхшироқ танишимиз учун",
                    ru: "Чтобы узнать вас лучше", en: "So we get to know you").t(lang))
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
            Text(L4(uz: "Kimsiz? Javobingizga qarab eng foydali vositalarni ko‘rsatamiz.",
                    kr: "Кимсиз? Жавобингизга қараб фойдали воситаларни кўрсатамиз.",
                    ru: "Кто вы? Покажем самые полезные инструменты.",
                    en: "Who are you? We'll show the most useful tools.").t(lang))
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.55))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(PERSONA_ROLES) { r in
                        Button {
                            HapticManager.shared.fire(.selection)
                            role = r
                            path.append(.value)   // native push → native slide + back
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
                Text(r.title.t(lang)).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text(r.tagline.t(lang)).font(.system(size: 12.5)).foregroundColor(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(LinearGradient(colors: [r.accent.opacity(0.5), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }

    // MARK: Step 1 — tailored value (real photo)
    @ViewBuilder private var valueStep: some View {
        if let r = role {
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
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.1)))

                    Text(L4(uz: "Ajoyib! Salom AI siz uchun:", kr: "Ажойиб! Салом AI сиз учун:",
                            ru: "Отлично! Salom AI для вас:", en: "Great! Salom AI for you:").t(lang))
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.white)

                    VStack(spacing: 10) {
                        ForEach(Array(r.values.enumerated()), id: \.offset) { _, v in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundColor(r.accent)
                                Text(v.t(lang)).font(.system(size: 14.5, weight: .medium)).foregroundColor(.white.opacity(0.92))
                                Spacer(minLength: 0)
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 24)
            }
            primaryButton(L4(uz: "Davom etish", kr: "Давом этиш", ru: "Продолжить", en: "Continue").t(lang)) {
                path.append(.goals)
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
    }

    // MARK: Step 2 — goals
    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L4(uz: "Nima bilan boshlaymiz?", kr: "Нима билан бошлаймиз?", ru: "С чего начнём?", en: "Where shall we start?").t(lang))
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
            Text(L4(uz: "Bir nechtasini tanlang (ixtiyoriy).", kr: "Бир нечтасини танланг (ихтиёрий).",
                    ru: "Выберите несколько (необязательно).", en: "Pick a few (optional).").t(lang))
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.55))

            ScrollView(showsIndicators: false) {
                FlowChips(goals: $goals, lang: lang)
                    .padding(.top, 18).padding(.bottom, 24)
            }
            primaryButton(L4(uz: "Tayyor", kr: "Тайёр", ru: "Готово", en: "Done").t(lang)) {
                HapticManager.shared.fire(.success)
                onComplete(role?.id, Array(goals))
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(backdrop(role?.accent ?? defaultAccent))
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
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
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
            .fill(Color.white.opacity(0.06))
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, Color.white.opacity(0.18), .clear],
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

    var body: some View {
        // Simple 2-column grid keeps it robust across iOS versions.
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(PERSONA_GOALS) { g in
                let on = goals.contains(g.id)
                Button {
                    HapticManager.shared.fire(.selection)
                    if on { goals.remove(g.id) } else { goals.insert(g.id) }
                } label: {
                    HStack(spacing: 8) {
                        Text(g.emoji).font(.system(size: 18))
                        Text(g.label.t(lang)).font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                        if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.cyan) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(on ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: on ? 1.5 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
