//
//  IlovalarView.swift
//  Salom-Ai-iOS
//
//  The "Ilovalar" hub — every Salom AI mini-tool as a grid (matches the web hub).
//  Tapping a tile switches the main section. Tiles show remote artwork from
//  salom-ai.uz/apps/<key>.webp when present (same asset the web uses); until
//  then a branded gradient + 3D icon is shown.
//

import SwiftUI

struct IlovalarView: View {
    var onOpen: (MainSection) -> Void = { _ in }
    var onOpenRemote: (RemoteMiniApp) -> Void = { _ in }
    var onMenu: () -> Void = {}
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    @State private var searchText = ""

    struct Copy {
        let uz: String
        let cyrl: String
        let ru: String
        let en: String

        func pick(_ languageCode: String) -> String {
            switch languageCode {
            case "uz-Cyrl": cyrl
            case "ru": ru
            case "en": en
            default: uz
            }
        }
    }

    fileprivate struct Tile: Identifiable {
        let id = UUID()
        let section: MainSection   // where tapping the tile navigates
        let key: String            // artwork filename → salom-ai.uz/apps/<key>.webp
        let n3d: String            // fallback 3D icon slug
        let title: Copy
        let subtitle: Copy
        let colors: [Color]
        let big: Bool
    }

    private let tiles: [Tile] = [
        Tile(section: .ish, key: "work", n3d: "briefcase",
             title: .init(uz: "Ish hujjatlari", cyrl: "Иш ҳужжатлари", ru: "Рабочие документы", en: "Work documents"),
             subtitle: .init(uz: "Tijorat taklifi, shartnoma, hisobot…", cyrl: "Тижорат таклифи, шартнома, ҳисобот…", ru: "Предложения, договоры, отчёты…", en: "Proposals, contracts, reports…"),
             colors: [Color(hex: "#8B5CF6"), Color(hex: "#06B6D4")], big: true),
        Tile(section: .dtm, key: "dtm", n3d: "grad",
             title: .init(uz: "DTM testlari", cyrl: "DTM тестлари", ru: "Тесты DTM", en: "DTM tests"),
             subtitle: .init(uz: "Imtihonga tayyorgarlik", cyrl: "Имтиҳонга тайёргарлик", ru: "Подготовка к экзаменам", en: "Exam preparation"),
             colors: [Color(hex: "#10B981"), Color(hex: "#14B8A6")], big: true),
        Tile(section: .presentations, key: "presentations", n3d: "present",
             title: .init(uz: "Taqdimotlar", cyrl: "Тақдимотлар", ru: "Презентации", en: "Presentations"),
             subtitle: .init(uz: "PPTX / PDF", cyrl: "PPTX / PDF", ru: "PPTX / PDF", en: "PPTX / PDF"),
             colors: [Color(hex: "#F97316"), Color(hex: "#EC4899")], big: false),
        Tile(section: .referats, key: "referats", n3d: "books",
             title: .init(uz: "Referat / Insho", cyrl: "Реферат / Иншо", ru: "Реферат / Эссе", en: "Report / Essay"),
             subtitle: .init(uz: "Tayyor hujjat — bir necha daqiqada", cyrl: "Тайёр ҳужжат — бир неча дақиқада", ru: "Готовый документ за несколько минут", en: "A finished document in minutes"),
             colors: [Color(hex: "#2563EB"), Color(hex: "#4F46E5")], big: false),
        Tile(section: .chat, key: "image", n3d: "image",
             title: .init(uz: "Rasm yaratish", cyrl: "Расм яратиш", ru: "Создание изображений", en: "Image generation"),
             subtitle: .init(uz: "Matndan rasm", cyrl: "Матндан расм", ru: "Изображение из текста", en: "Text to image"),
             colors: [Color(hex: "#D946EF"), Color(hex: "#9333EA")], big: false),
        Tile(section: .realtime, key: "voice", n3d: "voice",
             title: .init(uz: "Ovozli suhbat", cyrl: "Овозли суҳбат", ru: "Голосовой чат", en: "Voice chat"),
             subtitle: .init(uz: "Gapirib suhbatlashing", cyrl: "Гапириб суҳбатлашинг", ru: "Общайтесь голосом", en: "Talk naturally"),
             colors: [Color(hex: "#F43F5E"), Color(hex: "#EF4444")], big: false),
    ]

    static let remoteApps: [RemoteMiniApp] = [
        .init(id: "document-explainer", title: .init(uz: "Hujjatni tushuntirish", cyrl: "Ҳужжатни тушунтириш", ru: "Объяснить документ", en: "Explain a document"), subtitle: .init(uz: "PDF va rasmdagi matn — sodda tilda", cyrl: "PDF ва расмдаги матн — содда тилда", ru: "PDF и фото — простыми словами", en: "PDF and photos in plain language"), imageKey: "document-explainer", colors: [.cyan, .indigo]),
        .init(id: "government-guide", title: .init(uz: "Davlat xizmatlari", cyrl: "Давлат хизматлари", ru: "Госуслуги", en: "Government services"), subtitle: .init(uz: "MyGov, hujjatlar va qadamlar", cyrl: "MyGov, ҳужжатлар ва қадамлар", ru: "MyGov, документы и шаги", en: "MyGov, documents and steps"), imageKey: "government-guide", colors: [.cyan, .blue]),
        .init(id: "tax-self-employed", title: .init(uz: "Soliq va bandlik", cyrl: "Солиқ ва бандлик", ru: "Налоги и самозанятость", en: "Tax & self-employment"), subtitle: .init(uz: "Rasmiy yo‘l va hisob", cyrl: "Расмий йўл ва ҳисоб", ru: "Официальный путь и расчёт", en: "Official path and estimate"), imageKey: "tax-self-employed", colors: [.green, .teal]),
        .init(id: "salary-employment", title: .init(uz: "Ish haqi va mehnat", cyrl: "Иш ҳақи ва меҳнат", ru: "Зарплата и труд", en: "Salary & employment"), subtitle: .init(uz: "Brutto-netto va mehnat staji", cyrl: "Брутто-нетто ва меҳнат стажи", ru: "Брутто-нетто и стаж", en: "Gross-net and work history"), imageKey: "salary-employment", colors: [.blue, .cyan]),
        .init(id: "vehicle-assistant", title: .init(uz: "Avtomobil yordamchisi", cyrl: "Автомобиль ёрдамчиси", ru: "Автопомощник", en: "Vehicle assistant"), subtitle: .init(uz: "Safar xarajati va rasmiy xizmatlar", cyrl: "Сафар харажати ва расмий хизматлар", ru: "Расход поездки и автоуслуги", en: "Trip cost and services"), imageKey: "vehicle-assistant", colors: [.indigo, .blue]),
        .init(id: "money-planner", title: .init(uz: "Oila byudjeti", cyrl: "Оила бюджети", ru: "Семейный бюджет", en: "Family budget"), subtitle: .init(uz: "Xarajat, qarz va jamg‘arma", cyrl: "Харажат, қарз ва жамғарма", ru: "Расходы, долги и накопления", en: "Expenses, debt and savings"), imageKey: "money-planner", colors: [.orange, .yellow]),
        .init(id: "job-assistant", title: .init(uz: "Ish topish yordamchisi", cyrl: "Иш топиш ёрдамчиси", ru: "Поиск работы", en: "Job search assistant"), subtitle: .init(uz: "CV, vakansiya va suhbat", cyrl: "CV, вакансия ва суҳбат", ru: "Резюме, вакансия и интервью", en: "CV, vacancy and interview"), imageKey: "job-assistant", colors: [.purple, .indigo]),
        .init(id: "migrant-helper", title: .init(uz: "Safar va migrant", cyrl: "Сафар ва мигрант", ru: "Поездки и миграция", en: "Travel & migrant guide"), subtitle: .init(uz: "Hujjat va xavfsizlik ro‘yxati", cyrl: "Ҳужжат ва хавфсизлик рўйхати", ru: "Документы и безопасность", en: "Documents and safety"), imageKey: "migrant-helper", colors: [.cyan, .teal]),
        .init(id: "family-benefits", title: .init(uz: "Oila va nafaqa", cyrl: "Оила ва нафақа", ru: "Семья и пособия", en: "Family & benefits"), subtitle: .init(uz: "Bola, bog‘cha va yordam xizmatlari", cyrl: "Бола, боғча ва ёрдам хизматлари", ru: "Дети, сад и помощь", en: "Child, kindergarten and support"), imageKey: "family-benefits", colors: [.pink, .red]),
        .init(id: "teacher-assistant", title: .init(uz: "O‘qituvchi yordamchisi", cyrl: "Ўқитувчи ёрдамчиси", ru: "Помощник учителя", en: "Teacher assistant"), subtitle: .init(uz: "Dars, test va baholash", cyrl: "Дарс, тест ва баҳолаш", ru: "Уроки, тесты и оценивание", en: "Lessons, quizzes and assessment"), imageKey: "teacher-assistant", colors: [.green, .cyan]),
        .init(id: "utilities-helper", title: .init(uz: "Kommunal yordamchi", cyrl: "Коммунал ёрдамчи", ru: "Коммунальный помощник", en: "Utilities helper"), subtitle: .init(uz: "Hisob va murojaatni tushuning", cyrl: "Ҳисоб ва мурожаатни тушунинг", ru: "Разбор счетов и обращений", en: "Bills and service requests"), imageKey: "utilities-helper", colors: [.cyan, .blue]),
        .init(id: "marketplace-seller", title: .init(uz: "Onlayn sotuvchi", cyrl: "Онлайн сотувчи", ru: "Онлайн-продавец", en: "Online seller"), subtitle: .init(uz: "Mahsulot kartasi va savdo", cyrl: "Маҳсулот картаси ва савдо", ru: "Карточка товара и продажи", en: "Listings and sales"), imageKey: "marketplace-seller", colors: [.orange, .pink]),
        .init(id: "voice-notes", title: .init(uz: "Ovozdan natija", cyrl: "Овоздан натижа", ru: "Голос в результат", en: "Voice note to action"), subtitle: .init(uz: "Xulosa, vazifa va tayyor matn", cyrl: "Хулоса, вазифа ва тайёр матн", ru: "Итог, задачи и готовый текст", en: "Summary, tasks and polished text"), imageKey: "voice-notes", colors: [.purple, .indigo]),
        .init(id: "farmer-assistant", title: .init(uz: "Dehqon yordamchisi", cyrl: "Деҳқон ёрдамчиси", ru: "Помощник фермера", en: "Farmer assistant"), subtitle: .init(uz: "Ekin, xarajat va mavsum rejasi", cyrl: "Экин, харажат ва мавсум режаси", ru: "Посевы, затраты и сезон", en: "Crops, costs and season plan"), imageKey: "farmer-assistant", colors: [.green, .teal]),
        .init(id: "health-visit", title: .init(uz: "Shifokorga tayyorgarlik", cyrl: "Шифокорга тайёргарлик", ru: "Подготовка к врачу", en: "Prepare for a doctor"), subtitle: .init(uz: "Alomat va savollarni tartiblang", cyrl: "Аломат ва саволларни тартибланг", ru: "Симптомы и вопросы по порядку", en: "Organize symptoms and questions"), imageKey: "health-visit", colors: [.pink, .red]),
    ]

    private var filteredRemoteApps: [RemoteMiniApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return Self.remoteApps }
        return Self.remoteApps.filter {
            $0.title.pick(languageCode).lowercased().contains(query)
                || $0.subtitle.pick(languageCode).lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        GlassIconButton(systemName: "line.3.horizontal", size: 40) { onMenu() }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Copy(uz: "Ilovalar", cyrl: "Иловалар", ru: "Приложения", en: "Apps").pick(languageCode))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(SalomTheme.Colors.textPrimary)
                            Text(Copy(uz: "Barcha vositalar — bir joyda", cyrl: "Барча воситалар — бир жойда", ru: "Все инструменты в одном месте", en: "All tools in one place").pick(languageCode))
                                .font(.system(size: 13))
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(tiles) { tile in
                            Button {
                                HapticManager.shared.fire(.lightImpact)
                                onOpen(tile.section)
                            } label: { TileCardView(tile: tile, languageCode: languageCode) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(Copy(uz: "O‘zbekiston uchun yordamchilar", cyrl: "Ўзбекистон учун ёрдамчилар", ru: "Помощники для Узбекистана", en: "Helpers for Uzbekistan").pick(languageCode))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(SalomTheme.Colors.textPrimary)

                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                            TextField(
                                Copy(uz: "Nima qilmoqchisiz?", cyrl: "Нима қилмоқчисиз?", ru: "Что вы хотите сделать?", en: "What do you want to do?").pick(languageCode),
                                text: $searchText
                            )
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 50)
                        .background(SalomTheme.Colors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SalomTheme.Colors.border))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                        ForEach(filteredRemoteApps) { app in
                            Button {
                                HapticManager.shared.fire(.lightImpact)
                                Analytics.shared.track("mini_app_open", ["app_id": app.id, "surface": "ios_apps_hub"])
                                onOpenRemote(app)
                            } label: {
                                RemoteTileCardView(app: app, languageCode: languageCode)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Big house-ad showcase (our own products) — free users only.
                    ProductShowcaseView()
                }
                .padding(.bottom, 24)
            }
        }
    }
}

private struct RemoteTileCardView: View {
    let app: RemoteMiniApp
    let languageCode: String

    var body: some View {
        ZStack {
            LinearGradient(colors: app.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            AsyncImage(url: URL(string: "https://salom-ai.uz/apps/\(app.imageKey).webp")) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 5) {
                Spacer()
                Text(app.title.pick(languageCode))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(app.subtitle.pick(languageCode))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(13)
        }
        .frame(height: 174)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
}

// A single hub tile. Loads remote artwork (salom-ai.uz/apps/<key>.webp) over the
// branded gradient; when the artwork loads the 3D icon is hidden so it "replaces"
// the icon, otherwise the gradient + icon are shown.
private struct TileCardView: View {
    let tile: IlovalarView.Tile
    let languageCode: String
    @State private var artworkLoaded = false

    var body: some View {
        ZStack {
            LinearGradient(colors: tile.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            AsyncImage(url: URL(string: "https://salom-ai.uz/apps/\(tile.key).webp")) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                        .onAppear { artworkLoaded = true }
                } else {
                    Color.clear
                }
            }

            LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                if !artworkLoaded {
                    Icon3DView(slug: tile.n3d, size: tile.big ? 48 : 40)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                }
                Spacer(minLength: 0)
                Text(tile.title.pick(languageCode))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tile.subtitle.pick(languageCode))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
        }
        .frame(height: tile.big ? 190 : 165)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
