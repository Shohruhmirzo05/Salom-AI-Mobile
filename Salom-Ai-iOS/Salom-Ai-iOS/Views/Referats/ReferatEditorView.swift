//
//  ReferatEditorView.swift
//  Salom-Ai-iOS
//
//  View, AI-chat-edit and export (DOCX/PDF) a referat document. Mirrors the web
//  /referats/:id editor and the iOS Presentation editor.
//

import SwiftUI

struct ReferatEditorView: View {
    let referatId: Int

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: ReferatL { ReferatL(languageCode) }

    @State private var referat: Referat?
    @State private var doc: ReferatDoc?
    @State private var loadFailed = false

    // chat edit
    @State private var instruction = ""
    @State private var editing = false
    @State private var lastReply: String?

    // export
    @State private var exporting = false
    @State private var shareItem: ReferatShareItem?
    @State private var showPaywall = false

    private var isLocked: Bool { referat?.mode == "preview" || (referat?.lockedSections ?? 0) > 0 }
    private var canExport: Bool { referat?.canExport ?? true }

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            if loadFailed {
                failedState
            } else if referat == nil || referat?.status == "generating" {
                buildingState
            } else if referat?.status == "failed" || doc == nil {
                failedState
            } else {
                editor
            }
        }
        .task { await loadAndPoll() }
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet() }
    }

    // MARK: editor

    private var editor: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(doc?.title ?? referat?.title ?? "—")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(doc?.sections ?? [], id: \.stableId) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.heading)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, p in
                                Text(p)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(3)
                            }
                        }
                    }

                    if let refs = doc?.references, !refs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L.references)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            ForEach(Array(refs.enumerated()), id: \.offset) { i, r in
                                Text("\(i + 1). \(r)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if isLocked { lockedCard }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .padding(.bottom, 24)
            }

            chatBar
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    .padding(8).background(Circle().fill(Color.white.opacity(0.08)))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(referat?.title ?? "—").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text("\(referat?.wordCount ?? 0) \(L.words)\(referat?.mode == "preview" ? " · \(L.previewBadge)" : "")")
                    .font(.caption2).foregroundColor(.white.opacity(0.45))
            }
            Spacer()

            Menu {
                Button { Task { await runExport("docx") } } label: { Label("Word (.docx)", systemImage: "doc.fill") }
                Button { Task { await runExport("pdf") } } label: { Label("PDF (.pdf)", systemImage: "doc.richtext") }
            } label: {
                HStack(spacing: 6) {
                    if exporting { ProgressView().tint(.white).scaleEffect(0.7) } else { Image(systemName: "square.and.arrow.up") }
                    Text(exporting ? L.exporting : L.download).font(.system(size: 13, weight: .semibold))
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

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.lockedTitle).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(L.lockedDesc).font(.subheadline).foregroundColor(.white.opacity(0.65))
            Button { showPaywall = true } label: {
                Label(L.upgrade, systemImage: "crown.fill").fontWeight(.semibold)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white).clipShape(Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [Color.orange.opacity(0.14), Color.purple.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.orange.opacity(0.3)))
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
                RoundedRectangle(cornerRadius: 26).fill(LinearGradient(colors: [Color(hex: "#2563EB"), Color(hex: "#4F46E5")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 90, height: 90)
                Image(systemName: "text.book.closed.fill").font(.system(size: 32)).foregroundColor(.white)
            }
            ProgressView().tint(.white)
            Text(L.building).font(.subheadline).foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }

    private var failedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 34)).foregroundColor(.red)
            Text(referat?.error ?? L.failed).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center).padding(.horizontal, 30)
            Button(L.back) { dismiss() }.foregroundColor(.cyan)
        }
    }

    // MARK: actions

    private func loadAndPoll() async {
        while !Task.isCancelled {
            do {
                let r = try await ReferatService.get(referatId)
                referat = r
                if let d = r.doc { doc = d }
                if r.status == "generating" {
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

    private func sendEdit() async {
        let text = instruction.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !editing else { return }
        editing = true; instruction = ""; lastReply = nil
        do {
            let res = try await ReferatService.chat(referatId, instruction: text)
            doc = res.doc
            lastReply = res.reply.isEmpty ? "✓" : res.reply
        } catch {
            lastReply = nil
            instruction = text
        }
        editing = false
    }

    private func runExport(_ fmt: String) async {
        guard !exporting else { return }
        if !canExport { showPaywall = true; return }
        exporting = true
        do {
            let job = try await ReferatService.export(referatId, format: fmt)
            var status = job
            var tries = 0
            while status.status == "processing" && tries < 60 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                status = try await ReferatService.exportStatus(job.id)
                tries += 1
            }
            if status.status == "ready", let urlStr = status.fileUrl, let remote = URL(string: urlStr) {
                Analytics.shared.track("referat_exported", ["format": fmt])
                let local = await downloadToFile(remote, format: fmt)
                exporting = false
                shareItem = ReferatShareItem(url: local ?? remote)
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
            let base = (referat?.title ?? "").trimmingCharacters(in: .whitespaces)
            let safe = (base.isEmpty ? "Salom-AI-referat" : base)
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

private struct ReferatShareItem: Identifiable { let id = UUID(); let url: URL }
