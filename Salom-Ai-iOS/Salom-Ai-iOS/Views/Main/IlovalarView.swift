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
    var onMenu: () -> Void = {}
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"

    fileprivate struct Copy {
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

                    // Big house-ad showcase (our own products) — free users only.
                    ProductShowcaseView()
                }
                .padding(.bottom, 24)
            }
        }
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
