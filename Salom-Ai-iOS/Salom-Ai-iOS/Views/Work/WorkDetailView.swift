//
//  WorkDetailView.swift
//  Salom-Ai-iOS
//
//  Guided task form → generate → poll → render Markdown → export/share + AI edit.
//  Mirrors PresentationEditorView.swift (poll + export→download→share pattern).
//

import SwiftUI

private struct WorkShareItem: Identifiable { let id = UUID(); let url: URL }

struct WorkDetailView: View {
    // Form mode when `taskDef` is set; view mode when `docId` (or after generate).
    let taskDef: WorkTask?
    let docLang: String
    @State private var currentDocId: Int?

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"

    @State private var values: [String: String] = [:]
    @State private var busy = false
    @State private var errText: String?
    @State private var doc: WorkDoc?
    @State private var pollTask: Task<Void, Never>?
    @State private var exporting: String?
    @State private var instruction = ""
    @State private var editing = false
    @State private var shareItem: WorkShareItem?
    @State private var showPaywall = false

    private var L: IshL { IshL(languageCode) }

    init(task: WorkTask? = nil, docId: Int? = nil, docLang: String) {
        self.taskDef = task
        self.docLang = docLang
        _currentDocId = State(initialValue: docId)
    }

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                if currentDocId == nil, let taskDef { formView(taskDef) }
                else { docView }
            }
        }
        .onDisappear { pollTask?.cancel() }
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet() }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                HStack(spacing: 4) { Image(systemName: "chevron.left"); Text(L.back) }
                    .font(.system(size: 15)).foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Form
    @ViewBuilder private func formView(_ task: WorkTask) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(task.title.pick(languageCode)).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                Text(task.subtitle.pick(languageCode)).font(.system(size: 14)).foregroundColor(.white.opacity(0.55))

                ForEach(task.inputs, id: \.key) { f in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 2) {
                            Text(f.label.pick(languageCode)).font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.75))
                            if f.required { Text("*").foregroundColor(.red) }
                        }
                        field(f)
                    }
                }

                if let errText {
                    Text(errText).font(.system(size: 13)).foregroundColor(.red)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.1)))
                }

                Button { Task { await generate(task) } } label: {
                    HStack {
                        if busy { ProgressView().tint(.white); Text(L.creating) }
                        else { Image(systemName: "sparkles"); Text(L.create) }
                    }
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(LinearGradient(colors: [Color(SalomTheme.Colors.accentPrimary), Color(SalomTheme.Colors.accentSecondary)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(busy)
            }
            .padding(16).padding(.bottom, 40)
        }
    }

    @ViewBuilder private func field(_ f: WorkTaskInput) -> some View {
        let binding = Binding(get: { values[f.key] ?? "" }, set: { values[f.key] = $0 })
        switch f.type {
        case "textarea":
            TextField(f.placeholder?.pick(languageCode) ?? "", text: binding, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.plain).padding(11)
                .background(fieldBG).foregroundColor(.white)
        case "select":
            Menu {
                ForEach(f.options ?? [], id: \.uz) { opt in
                    let v = opt.pick(languageCode)
                    Button(v) { values[f.key] = v }
                }
            } label: {
                HStack {
                    Text(values[f.key]?.isEmpty == false ? values[f.key]! : L.select)
                        .foregroundColor(values[f.key]?.isEmpty == false ? .white : .white.opacity(0.4))
                    Spacer(); Image(systemName: "chevron.down").foregroundColor(.white.opacity(0.4))
                }.padding(11).background(fieldBG)
            }
        default:
            TextField(f.placeholder?.pick(languageCode) ?? "", text: binding)
                .textFieldStyle(.plain).padding(11).background(fieldBG).foregroundColor(.white)
        }
    }

    private var fieldBG: some View {
        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1)))
    }

    // MARK: - Document view
    @ViewBuilder private var docView: some View {
        if let d = doc, d.status == "ready" {
            VStack(spacing: 0) {
                exportBar(d)
                ScrollView {
                    MarkdownText(text: d.content ?? "")
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                editBar
            }
        } else if let d = doc, d.status == "failed" {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "exclamationmark.triangle").font(.system(size: 30)).foregroundColor(.orange)
                Text(L.failed).foregroundColor(.white)
                if let e = d.error { Text(e).font(.system(size: 12)).foregroundColor(.white.opacity(0.5)).multilineTextAlignment(.center).padding(.horizontal, 30) }
                Spacer()
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                ProgressView().tint(.white.opacity(0.7))
                Text(L.docGenerating).foregroundColor(.white.opacity(0.6)).font(.system(size: 14))
                Spacer()
            }
            .task { await poll() }
        }
    }

    private func exportBar(_ d: WorkDoc) -> some View {
        let fmts = d.outputFormat == "xlsx" ? ["xlsx", "pdf"] : ["docx", "pdf"]
        return HStack(spacing: 8) {
            Text(d.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1)
            Spacer()
            if d.canExport == true {
                ForEach(fmts, id: \.self) { fmt in
                    Button { Task { await runExport(fmt) } } label: {
                        HStack(spacing: 4) {
                            if exporting == fmt { ProgressView().tint(.white).scaleEffect(0.7) }
                            else { Image(systemName: "arrow.down.circle") }
                            Text(fmt.uppercased())
                        }
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    }.disabled(exporting != nil)
                }
            } else {
                Button { showPaywall = true } label: {
                    HStack(spacing: 4) { Image(systemName: "lock.fill"); Text("Pro") }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.black)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(LinearGradient(colors: [Color(SalomTheme.Colors.accentSecondary), Color(SalomTheme.Colors.accentPrimary)], startPoint: .leading, endPoint: .trailing)))
                }
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    private var editBar: some View {
        HStack(spacing: 8) {
            TextField(L.chatPlaceholder, text: $instruction)
                .textFieldStyle(.plain).padding(11).background(fieldBG).foregroundColor(.white)
            Button { Task { await runEdit() } } label: {
                if editing { ProgressView().tint(.white).scaleEffect(0.8) }
                else { Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)).foregroundColor(Color(SalomTheme.Colors.accentSecondary)) }
            }.disabled(editing || instruction.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12).background(.ultraThinMaterial)
    }

    // MARK: - Actions
    private func generate(_ task: WorkTask) async {
        for f in task.inputs where f.required {
            if (values[f.key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                errText = "«\(f.label.pick(languageCode))» — \(L.required)"; return
            }
        }
        busy = true; errText = nil
        do {
            let res = try await WorkService.generate(taskId: task.id, inputs: values, language: docLang)
            await MainActor.run { currentDocId = res.id; busy = false }
        } catch let APIError.server(status, _) where status == 403 {
            await MainActor.run { busy = false; showPaywall = true }
        } catch {
            await MainActor.run { busy = false; errText = L.failed }
        }
    }

    private func poll() async {
        guard let id = currentDocId else { return }
        while !Task.isCancelled {
            do {
                let d = try await WorkService.get(id)
                await MainActor.run { self.doc = d }
                if d.status == "generating" {
                    try await Task.sleep(nanoseconds: 1_800_000_000); continue
                }
                return
            } catch { return }
        }
    }

    private func runEdit() async {
        guard let id = currentDocId, !instruction.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        editing = true
        do {
            _ = try await WorkService.chat(id, instruction: instruction)
            let refreshed = try await WorkService.get(id)   // re-fetch the updated doc
            await MainActor.run { doc = refreshed; instruction = ""; editing = false }
        } catch let APIError.server(status, _) where status == 403 {
            await MainActor.run { editing = false; showPaywall = true }
        } catch {
            await MainActor.run { editing = false }
        }
    }

    private func runExport(_ fmt: String) async {
        guard let id = currentDocId else { return }
        exporting = fmt
        do {
            let job = try await WorkService.export(id, format: fmt)
            var status = job; var tries = 0
            while status.status == "processing" && tries < 60 {
                try await Task.sleep(nanoseconds: 1_500_000_000)
                status = try await WorkService.exportStatus(job.id); tries += 1
            }
            if status.status == "ready", let urlStr = status.fileUrl, let remote = URL(string: urlStr) {
                let local = await downloadToFile(remote, format: fmt)
                await MainActor.run { shareItem = WorkShareItem(url: local ?? remote); exporting = nil }
            } else {
                await MainActor.run { exporting = nil }
            }
        } catch let APIError.server(status, _) where status == 403 {
            await MainActor.run { exporting = nil; showPaywall = true }
        } catch {
            await MainActor.run { exporting = nil }
        }
    }

    private func downloadToFile(_ remote: URL, format: String) async -> URL? {
        do {
            let (tmp, _) = try await URLSession.shared.download(from: remote)
            let name = "Salom_AI_hujjat.\(format)"
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
            return dest
        } catch { return nil }
    }
}
