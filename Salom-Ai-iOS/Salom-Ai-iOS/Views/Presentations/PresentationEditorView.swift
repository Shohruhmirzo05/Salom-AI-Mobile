//
//  PresentationEditorView.swift
//  Salom-Ai-iOS
//
//  View, AI-chat-edit, theme, present, and export (PPTX/PDF) a deck.
//

import SwiftUI

struct PresentationEditorView: View {
    let presentationId: Int

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: PresoL { PresoL(languageCode) }

    @State private var preso: Presentation?
    @State private var deck: Deck?
    @State private var loadFailed = false
    @State private var current = 0
    @State private var presenting = false
    // Bumped on every deck/theme change to force the paged TabView to rebuild —
    // paged TabView caches rendered pages and won't refresh on data change alone.
    @State private var revision = 0

    // chat edit
    @State private var instruction = ""
    @State private var editing = false
    @State private var lastReply: String?

    // export
    @State private var exporting = false
    @State private var exportFmt = ""
    @State private var shareItem: ShareItem?

    private var style: DeckStyle { DeckStyles.style(preso?.theme) }
    private var slides: [PSlide] { deck?.slides ?? [] }

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            if loadFailed {
                failedState
            } else if preso == nil || preso?.status == "generating" {
                buildingState
            } else if preso?.status == "failed" || slides.isEmpty {
                failedState
            } else {
                editor
            }
        }
        .task { await loadAndPoll() }
        .fullScreenCover(isPresented: $presenting) {
            PresentMode(slides: slides, style: style, start: current)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: editor

    private var editor: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $current) {
                ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                    VStack {
                        ScaledSlide(slide: slide, style: style)
                            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                            .padding(.horizontal, 16)
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(maxHeight: .infinity)
            .id(revision)

            Text("\(min(current + 1, slides.count)) / \(slides.count)")
                .font(.caption).foregroundColor(.white.opacity(0.5)).padding(.bottom, 4)

            chatBar
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: { Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.white).padding(8).background(Circle().fill(Color.white.opacity(0.08))) }
            VStack(alignment: .leading, spacing: 1) {
                Text(preso?.title ?? "—").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text("\(slides.count) \(L.slides)").font(.caption2).foregroundColor(.white.opacity(0.45))
            }
            Spacer()

            Menu {
                ForEach(["midnight", "aurora", "minimal", "sand", "forest", "coral"], id: \.self) { t in
                    Button(t.capitalized) { Task { await changeTheme(t) } }
                }
            } label: { Image(systemName: "paintpalette").font(.system(size: 16)).foregroundColor(.white).padding(8).background(Circle().fill(Color.white.opacity(0.08))) }

            Button { presenting = true } label: { Image(systemName: "play.fill").font(.system(size: 14)).foregroundColor(.white).padding(8).background(Circle().fill(Color.white.opacity(0.08))) }

            Menu {
                Button { Task { await runExport("pptx") } } label: { Label("PowerPoint (.pptx)", systemImage: "doc.fill") }
                Button { Task { await runExport("pdf") } } label: { Label("PDF (.pdf)", systemImage: "doc.richtext") }
            } label: {
                HStack(spacing: 6) {
                    if exporting { ProgressView().tint(.white).scaleEffect(0.7) } else { Image(systemName: "square.and.arrow.up") }
                    Text(exporting ? L.exporting : L.export).font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)))
                .foregroundColor(.white)
            }
            .disabled(exporting)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }

    private var chatBar: some View {
        VStack(spacing: 6) {
            if let lastReply { Label(lastReply, systemImage: "sparkles").font(.caption).foregroundColor(.cyan).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4) }
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundColor(.cyan)
                    TextField(L.chatPlaceholder, text: $instruction, axis: .vertical)
                        .lineLimit(1...3).foregroundColor(.white).font(.system(size: 14))
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.06)))

                Button { Task { await sendEdit() } } label: {
                    if editing { ProgressView().tint(.white).scaleEffect(0.8) } else { Image(systemName: "arrow.up") }
                }
                .frame(width: 44, height: 44)
                .background(Circle().fill(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom)))
                .foregroundColor(.white)
                .disabled(editing || instruction.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(editing || instruction.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            if editing { Text(L.applying).font(.caption2).foregroundColor(.white.opacity(0.4)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4) }
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)
        .background(Color.white.opacity(0.03))
    }

    private var buildingState: some View {
        VStack(spacing: 18) {
            Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundColor(.white) }.frame(maxWidth: .infinity, alignment: .leading).padding()
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 26).fill(style.gradient).frame(width: 90, height: 90)
                Image(systemName: "sparkles").font(.system(size: 34)).foregroundColor(style.accent)
            }
            ProgressView().tint(.white)
            Text(L.buildingDeck).font(.subheadline).foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }

    private var failedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 34)).foregroundColor(.red)
            Text(preso?.error ?? L.failed).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center).padding(.horizontal, 30)
            Button(L.back) { dismiss() }.foregroundColor(.cyan)
        }
    }

    // MARK: actions

    private func loadAndPoll() async {
        while !Task.isCancelled {
            do {
                let p = try await PresentationService.get(presentationId)
                preso = p
                if let d = p.deck { deck = d }
                if p.status == "generating" {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }
                return
            } catch {
                loadFailed = true
                return
            }
        }
    }

    private func changeTheme(_ t: String) async {
        guard var p = preso else { return }
        p = Presentation(id: p.id, title: p.title, language: p.language, theme: t, slideCount: p.slideCount, status: p.status, error: p.error, deck: p.deck, createdAt: p.createdAt, updatedAt: p.updatedAt)
        preso = p
        revision += 1   // refresh slides with the new theme
        _ = try? await PresentationService.updateTheme(presentationId, theme: t)
    }

    private func sendEdit() async {
        let text = instruction.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !editing else { return }
        editing = true; instruction = ""; lastReply = nil
        do {
            let res = try await PresentationService.chat(presentationId, instruction: text)
            if current >= res.deck.slides.count { current = max(0, res.deck.slides.count - 1) }
            deck = res.deck
            revision += 1   // force the paged TabView to show the updated slides
            lastReply = res.reply.isEmpty ? "✓" : res.reply
        } catch {
            lastReply = nil
            instruction = text
        }
        editing = false
    }

    private func runExport(_ fmt: String) async {
        guard !exporting else { return }
        exporting = true; exportFmt = fmt
        do {
            let job = try await PresentationService.export(presentationId, format: fmt)
            var status = job
            var tries = 0
            while status.status == "processing" && tries < 60 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                status = try await PresentationService.exportStatus(job.id)
                tries += 1
            }
            if status.status == "ready", let urlStr = status.fileUrl, let remote = URL(string: urlStr) {
                Analytics.shared.track("presentation_exported", ["format": fmt])
                // Download the real file so the share sheet shares the .pptx/.pdf
                // itself (Save to Files, AirDrop, Telegram…) — not just a link.
                let local = await downloadToFile(remote, format: fmt)
                exporting = false
                shareItem = ShareItem(url: local ?? remote)
            } else {
                exporting = false
            }
        } catch {
            exporting = false
        }
    }

    private func downloadToFile(_ remote: URL, format: String) async -> URL? {
        do {
            let (tmp, _) = try await URLSession.shared.download(from: remote)
            let base = (preso?.title ?? "").trimmingCharacters(in: .whitespaces)
            let safe = (base.isEmpty ? "Salom-AI-presentatsiya" : base)
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).\(format)")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}

// MARK: - Present mode

private struct PresentMode: View {
    let slides: [PSlide]
    let style: DeckStyle
    let start: Int
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(slides.enumerated()), id: \.offset) { idx, slide in
                    ScaledSlide(slide: slide, style: style, cornerRadius: 0)
                        .frame(maxHeight: .infinity)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark").foregroundColor(.white).padding(10).background(Circle().fill(Color.white.opacity(0.15))) }
                }
                Spacer()
                Text("\(index + 1) / \(slides.count)").font(.caption).foregroundColor(.white.opacity(0.6)).padding(.bottom, 10)
            }
            .padding()
        }
        .onAppear { index = start }
        .statusBarHidden(true)
    }
}

// MARK: - Share sheet

private struct ShareItem: Identifiable { let id = UUID(); let url: URL }

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
