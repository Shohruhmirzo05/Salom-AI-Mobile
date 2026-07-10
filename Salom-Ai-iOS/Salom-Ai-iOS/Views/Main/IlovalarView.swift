//
//  IlovalarView.swift
//  Salom-Ai-iOS
//
//  The "Ilovalar" hub — every Salom AI mini-tool as a grid (matches the web hub).
//  Tapping a tile switches the main section. Replaces the per-feature rows that used
//  to clutter the side menu, so there's one clear place for all tools.
//

import SwiftUI

struct IlovalarView: View {
    var onOpen: (MainSection) -> Void = { _ in }
    var onMenu: () -> Void = {}

    private struct Tile: Identifiable {
        let id = UUID()
        let section: MainSection
        let n3d: String
        let colors: [Color]
        let big: Bool
    }

    private let tiles: [Tile] = [
        Tile(section: .ish, n3d: "briefcase", colors: [Color(hex: "#8B5CF6"), Color(hex: "#06B6D4")], big: true),
        Tile(section: .dtm, n3d: "grad", colors: [Color(hex: "#10B981"), Color(hex: "#14B8A6")], big: true),
        Tile(section: .presentations, n3d: "present", colors: [Color(hex: "#F97316"), Color(hex: "#EC4899")], big: false),
        Tile(section: .realtime, n3d: "voice", colors: [Color(hex: "#F43F5E"), Color(hex: "#EF4444")], big: false),
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
                            } label: { tileCard(tile) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func tileCard(_ tile: Tile) -> some View {
        ZStack {
            LinearGradient(colors: tile.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Icon3DView(slug: tile.n3d, size: tile.big ? 48 : 40)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                Spacer(minLength: 0)
                Text(tile.section.title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Text(tile.section.subtitle).font(.system(size: 11)).foregroundColor(.white.opacity(0.85)).lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
        }
        .frame(height: tile.big ? 185 : 150)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
