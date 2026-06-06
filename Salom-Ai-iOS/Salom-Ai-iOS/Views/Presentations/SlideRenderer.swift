//
//  SlideRenderer.swift
//  Salom-Ai-iOS
//
//  Renders a slide from deck JSON onto a fixed 1280x720 canvas, scaled to fit.
//  Layouts mirror the backend PPTX exporter so on-screen ≈ exported file.
//

import SwiftUI
import Kingfisher

// MARK: - Theme styles (mirror backend presentation_themes.py)

struct DeckStyle {
    let bg: Color
    let bg2: Color
    let text: Color
    let muted: Color
    let accent: Color
    let dark: Bool

    var gradient: LinearGradient {
        LinearGradient(colors: [bg, bg2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum DeckStyles {
    static let map: [String: DeckStyle] = [
        "midnight": DeckStyle(bg: Color(hex: "#0B1020"), bg2: Color(hex: "#131A33"), text: Color(hex: "#F4F6FB"), muted: Color(hex: "#9AA4C0"), accent: Color(hex: "#E0B15A"), dark: true),
        "aurora":   DeckStyle(bg: Color(hex: "#1A0B2E"), bg2: Color(hex: "#2B1055"), text: Color(hex: "#F6F2FF"), muted: Color(hex: "#B7A6D8"), accent: Color(hex: "#33E1ED"), dark: true),
        "minimal":  DeckStyle(bg: Color(hex: "#FFFFFF"), bg2: Color(hex: "#F4F5F7"), text: Color(hex: "#111418"), muted: Color(hex: "#6B7280"), accent: Color(hex: "#E23744"), dark: false),
        "sand":     DeckStyle(bg: Color(hex: "#F6F0E6"), bg2: Color(hex: "#EFE6D5"), text: Color(hex: "#2A2118"), muted: Color(hex: "#8A7A63"), accent: Color(hex: "#C56B3E"), dark: false),
        "forest":   DeckStyle(bg: Color(hex: "#0E1F17"), bg2: Color(hex: "#163224"), text: Color(hex: "#EDF7F0"), muted: Color(hex: "#9CC2AC"), accent: Color(hex: "#8BE06B"), dark: true),
        "coral":    DeckStyle(bg: Color(hex: "#FFF6F2"), bg2: Color(hex: "#FFE9E0"), text: Color(hex: "#2B1A16"), muted: Color(hex: "#9B7468"), accent: Color(hex: "#FF6B5B"), dark: false),
    ]
    static func style(_ id: String?) -> DeckStyle { map[id ?? "midnight"] ?? map["midnight"]! }
}

private let DESIGN_W: CGFloat = 1280
private let DESIGN_H: CGFloat = 720

// MARK: - Building blocks

private struct AccentBar: View {
    let style: DeckStyle
    var width: CGFloat = 130
    var body: some View { RoundedRectangle(cornerRadius: 6).fill(style.accent).frame(width: width, height: 9) }
}

private struct BulletList: View {
    let bullets: [String]
    let style: DeckStyle
    var size: CGFloat = 26
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(bullets.enumerated()), id: \.offset) { _, b in
                HStack(alignment: .top, spacing: 14) {
                    Text("•").font(.system(size: size, weight: .heavy)).foregroundColor(style.accent)
                    Text(b).font(.system(size: size, weight: .regular)).foregroundColor(style.text).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct SlideImage: View {
    let url: String?
    var body: some View {
        if let url, let u = URL(string: url) {
            // Kingfisher caches to disk → no re-download on every page swipe,
            // which is what made AsyncImage feel slow inside the paged TabView.
            KFImage(u)
                .placeholder { Color.white.opacity(0.06).shimmering(active: true) }
                .fade(duration: 0.2)
                .cacheOriginalImage()
                .resizable()
                .scaledToFill()
        } else {
            Color.black.opacity(0.12)
        }
    }
}

// MARK: - The fixed-size canvas

struct SlideCanvas: View {
    let slide: PSlide
    let style: DeckStyle
    private let pad: CGFloat = 86

    var body: some View {
        ZStack { content }
            .frame(width: DESIGN_W, height: DESIGN_H)
            .background(style.gradient)
            .clipped()
    }

    @ViewBuilder private var content: some View {
        switch slide.layout {
        case "cover": cover
        case "section": section
        case "image_left": imageLeft
        case "two_column": twoColumn
        case "stats": stats
        case "quote": quote
        case "closing": closing
        default: bullets
        }
    }

    private func heading(_ size: CGFloat, _ color: Color? = nil) -> some ViewModifier {
        HeadingMod(size: size, color: color ?? style.text)
    }

    // cover
    private var cover: some View {
        ZStack(alignment: .leading) {
            if let url = slide.image?.url {
                SlideImage(url: url).frame(width: DESIGN_W, height: DESIGN_H).clipped()
                Color.black.opacity(0.42)
            }
            VStack(alignment: .leading, spacing: 26) {
                AccentBar(style: style)
                Text(slide.title ?? "").modifier(heading(76, slide.image?.url != nil ? .white : style.text))
                if let s = slide.subtitle {
                    Text(s).font(.system(size: 32)).foregroundColor(slide.image?.url != nil ? Color.white.opacity(0.9) : style.muted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, pad)
        }
    }

    private var section: some View {
        VStack(alignment: .leading, spacing: 24) {
            AccentBar(style: style, width: 90)
            Text(slide.title ?? "").modifier(heading(60))
            if let s = slide.subtitle { Text(s).font(.system(size: 30)).foregroundColor(style.muted) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, pad)
        .background(style.bg2)
    }

    private var titleHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            AccentBar(style: style)
            Text(slide.title ?? "").modifier(heading(46))
        }
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 36) {
            titleHeader
            if let url = slide.image?.url {
                HStack(alignment: .top, spacing: 36) {
                    BulletList(bullets: slide.bullets ?? [], style: style, size: 26).frame(maxWidth: .infinity, alignment: .leading)
                    SlideImage(url: url).frame(width: 440, height: 430).clipped().cornerRadius(24)
                }
            } else {
                BulletList(bullets: slide.bullets ?? [], style: style, size: 30)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, pad).padding(.top, 88)
    }

    private var imageLeft: some View {
        HStack(spacing: 0) {
            SlideImage(url: slide.image?.url).frame(width: 540, height: DESIGN_H).clipped()
            VStack(alignment: .leading, spacing: 30) {
                AccentBar(style: style)
                Text(slide.title ?? "").modifier(heading(44))
                BulletList(bullets: slide.bullets ?? [], style: style, size: 24)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 56).padding(.top, 90)
        }
    }

    private var twoColumn: some View {
        VStack(alignment: .leading, spacing: 30) {
            titleHeader
            HStack(spacing: 40) {
                column(slide.left)
                column(slide.right)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, pad).padding(.top, 88)
    }

    private func column(_ col: PColumn?) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(col?.heading ?? "").font(.system(size: 30, weight: .heavy)).foregroundColor(style.accent)
            BulletList(bullets: col?.bullets ?? [], style: style, size: 22)
            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 24).fill(style.bg2))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(style.accent, lineWidth: 1.5))
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 40) {
            titleHeader
            HStack(spacing: 40) {
                ForEach(Array((slide.stats ?? []).prefix(3).enumerated()), id: \.offset) { _, st in
                    VStack(spacing: 16) {
                        Text(st.value ?? "").font(.system(size: 78, weight: .heavy)).foregroundColor(style.accent).minimumScaleFactor(0.5).lineLimit(1)
                        Text(st.label ?? "").font(.system(size: 24)).foregroundColor(style.text).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .background(RoundedRectangle(cornerRadius: 28).fill(style.bg2))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, pad).padding(.top, 88)
    }

    private var quote: some View {
        ZStack(alignment: .topLeading) {
            style.bg2
            Text("\u{201C}").font(.system(size: 220, weight: .heavy)).foregroundColor(style.accent).padding(.leading, 60).padding(.top, -20)
            VStack(alignment: .leading, spacing: 36) {
                Text(slide.quote ?? "").modifier(heading(48))
                if let a = slide.author { Text("— \(a)").font(.system(size: 28)).foregroundColor(style.muted) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 120)
        }
    }

    private var closing: some View {
        VStack(alignment: .leading, spacing: 26) {
            AccentBar(style: style, width: 110)
            Text(slide.title ?? "Rahmat!").modifier(heading(70))
            if let s = slide.subtitle { Text(s).font(.system(size: 30)).foregroundColor(style.muted) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, pad)
    }
}

private struct HeadingMod: ViewModifier {
    let size: CGFloat
    let color: Color
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .heavy)).foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Responsive wrapper

struct ScaledSlide: View {
    let slide: PSlide
    let style: DeckStyle
    var cornerRadius: CGFloat = 16

    var body: some View {
        // Color.clear DOES honor aspectRatio (a greedy GeometryReader does not),
        // so this reliably yields a 16:9 box. The overlay GeometryReader then
        // measures that box and scales the fixed 1280x720 canvas to fill it.
        Color.clear
            .aspectRatio(DESIGN_W / DESIGN_H, contentMode: .fit)
            .overlay(
                GeometryReader { geo in
                    SlideCanvas(slide: slide, style: style)
                        .frame(width: DESIGN_W, height: DESIGN_H)
                        .scaleEffect(geo.size.width / DESIGN_W, anchor: .topLeading)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
