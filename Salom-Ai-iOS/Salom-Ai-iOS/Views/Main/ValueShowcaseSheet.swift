//
//  ValueShowcaseSheet.swift
//  Salom-Ai-iOS
//
//  First-run "what can you do with Salom AI?" popup — mirrors the web showcase.
//  Educates users on the breadth (chat, presentations, DTM, voice, images,
//  referat) so they stop treating it as a plain chatbot, seeds Pro desire, and
//  routes to each section. Shown once (UserDefaults) + re-openable.
//

import SwiftUI

extension Notification.Name {
    /// Switch the main section. userInfo["section"] = MainSection.rawValue.
    static let openSection = Notification.Name("salom.openSection")
    /// Re-open the value showcase from anywhere.
    static let showValueShowcase = Notification.Name("salom.showValueShowcase")
}

struct ShowcaseItem: Identifiable {
    let id = UUID()
    let n3d: String        // 3D icon slug (salom-ai.uz/icons3d)
    let title: String
    let desc: String
    let pro: Bool
    let section: String?   // MainSection rawValue to open, or nil = stay in chat
}

struct ValueShowcaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSeePro: () -> Void = {}

    private let items: [ShowcaseItem] = [
        .init(n3d: "briefcase", title: "Ish — hujjatlar", desc: "Tijorat taklifi, shartnoma, hisobot…", pro: true, section: "ish"),
        .init(n3d: "chat", title: "Aqlli chat", desc: "Savol bering, yozing, tarjima qiling", pro: false, section: "chat"),
        .init(n3d: "present", title: "Taqdimotlar", desc: "PPTX / PDF — bir necha soniyada", pro: true, section: "presentations"),
        .init(n3d: "grad", title: "DTM tayyorgarlik", desc: "Fanlar bo‘yicha testlar va tahlil", pro: false, section: "dtm"),
        .init(n3d: "voice", title: "Ovozli rejim", desc: "Gapiring — javobni eshiting", pro: false, section: "realtime"),
        .init(n3d: "image", title: "Rasm yaratish", desc: "Matndan chiroyli rasm", pro: true, section: nil),
        .init(n3d: "books", title: "Referat va insho", desc: "Chatda so‘rang — tayyor hujjat", pro: true, section: nil),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack(alignment: .top) {
                        Image(.appIconTransparent)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.55))
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.06)).clipShape(Circle())
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Salom AI bilan nimalar qila olasiz?")
                            .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                        Text("Bu shunchaki chat emas — o‘quv va ish yordamchisi 👇")
                            .font(.system(size: 14)).foregroundColor(.white.opacity(0.55))
                    }

                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            Button { open(item) } label: { row(item) }
                                .buttonStyle(.plain)
                        }
                    }

                    VStack(spacing: 10) {
                        Button { dismiss() } label: {
                            HStack { Text("Boshlash"); Image(systemName: "arrow.right") }
                                .font(.system(size: 16, weight: .semibold)).foregroundColor(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.cyan).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSeePro() }
                        } label: {
                            HStack { Image(systemName: "crown.fill"); Text("Pro imkoniyatlarni ko‘rish") }
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(Color.yellow.opacity(0.9))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(LinearGradient(colors: [.yellow.opacity(0.18), .orange.opacity(0.18)], startPoint: .leading, endPoint: .trailing))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.yellow.opacity(0.3)))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder private func row(_ item: ShowcaseItem) -> some View {
        HStack(spacing: 12) {
            Icon3DView(slug: item.n3d, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    if item.pro {
                        HStack(spacing: 2) {
                            Image(systemName: "crown.fill").font(.system(size: 8))
                            Text("Pro").font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(Color.yellow.opacity(0.9))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.15))
                        .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.25)))
                        .clipShape(Capsule())
                    }
                }
                Text(item.desc).font(.system(size: 12.5)).foregroundColor(.white.opacity(0.5)).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.25))
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }

    private func open(_ item: ShowcaseItem) {
        Analytics.shared.track("showcase_card", ["card": item.title, "pro": item.pro])
        dismiss()
        // Route to the section (if any) after the sheet closes.
        if let section = item.section {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NotificationCenter.default.post(name: .openSection, object: nil, userInfo: ["section": section])
            }
        }
    }
}
