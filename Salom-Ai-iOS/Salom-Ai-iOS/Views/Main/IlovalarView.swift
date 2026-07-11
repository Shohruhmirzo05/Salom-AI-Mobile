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

    fileprivate struct Tile: Identifiable {
        let id = UUID()
        let section: MainSection   // where tapping the tile navigates
        let key: String            // artwork filename → salom-ai.uz/apps/<key>.webp
        let n3d: String            // fallback 3D icon slug
        let title: String
        let subtitle: String
        let colors: [Color]
        let big: Bool
    }

    private let tiles: [Tile] = [
        Tile(section: .ish, key: "work", n3d: "briefcase",
             title: "Ish hujjatlar", subtitle: "Tijorat taklifi, shartnoma, hisobot…",
             colors: [Color(hex: "#8B5CF6"), Color(hex: "#06B6D4")], big: true),
        Tile(section: .dtm, key: "dtm", n3d: "grad",
             title: "DTM testlari", subtitle: "Imtihonga tayyorgarlik",
             colors: [Color(hex: "#10B981"), Color(hex: "#14B8A6")], big: true),
        Tile(section: .presentations, key: "presentations", n3d: "present",
             title: "Taqdimotlar", subtitle: "PPTX / PDF",
             colors: [Color(hex: "#F97316"), Color(hex: "#EC4899")], big: false),
        Tile(section: .referats, key: "referats", n3d: "books",
             title: "Referat / Insho", subtitle: "Tayyor hujjat — bir necha daqiqada",
             colors: [Color(hex: "#2563EB"), Color(hex: "#4F46E5")], big: false),
        Tile(section: .chat, key: "image", n3d: "image",
             title: "Rasm yaratish", subtitle: "Matndan rasm",
             colors: [Color(hex: "#D946EF"), Color(hex: "#9333EA")], big: false),
        Tile(section: .realtime, key: "voice", n3d: "voice",
             title: "Ovozli suhbat", subtitle: "Gapirib suhbatlashing",
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
                            Text("Ilovalar").font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                            Text("Barcha vositalar — bir joyda").font(.system(size: 13)).foregroundColor(.white.opacity(0.55))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(tiles) { tile in
                            Button {
                                HapticManager.shared.fire(.lightImpact)
                                onOpen(tile.section)
                            } label: { TileCardView(tile: tile) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
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
                Text(tile.title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Text(tile.subtitle).font(.system(size: 11)).foregroundColor(.white.opacity(0.85)).lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
        }
        .frame(height: tile.big ? 185 : 150)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
