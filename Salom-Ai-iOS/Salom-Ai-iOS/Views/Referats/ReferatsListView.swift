//
//  ReferatsListView.swift
//  Salom-Ai-iOS
//
//  Hub for the AI referat / insho writer: a create form (topic, length,
//  language, level), a "show don't give" preview note for free users, and the
//  list of the user's referats. Mirrors the web /referats page.
//

import SwiftUI

private struct ReferatRef: Identifiable { let id: Int }

struct ReferatsListView: View {
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: ReferatL { ReferatL(languageCode) }

    @State private var config: ReferatConfig?
    @State private var items: [ReferatSummary] = []
    @State private var loading = true

    @State private var topic = ""
    @State private var audience = ""
    @State private var words = 800
    @State private var docLang = "uz"
    @State private var creating = false
    @State private var errorText: String?

    @State private var openRef: ReferatRef?
    @State private var showPaywall = false

    private let lengthOptions = [600, 800, 1200, 1800, 2500]

    private var isPremiumLocked: Bool { config?.enabled == false }
    private var isPreview: Bool { config?.mode == "preview" }
    private var freeDailyReached: Bool { isPreview && (config?.canCreate == false) }
    private var remaining: Int? { if let c = config, c.limit > 0 { return max(0, c.limit - c.used) }; return nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if loading {
                    ProgressView().tint(SalomTheme.Colors.accentPrimary).frame(maxWidth: .infinity).padding(.top, 60)
                } else if isPremiumLocked {
                    premiumUpsell
                } else {
                    createCard
                }
                listSection
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await reload(); Analytics.shared.track("feature_opened", ["feature": "referats"]) }
        .fullScreenCover(item: $openRef, onDismiss: { Task { await refreshList() } }) { ref in
            ReferatEditorView(referatId: ref.id)
        }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet(context: .referatExport, source: "ios_referats") }
    }

    // MARK: create

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(L.topicPlaceholder, text: $topic, axis: .vertical)
                .lineLimit(2...5)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(SalomTheme.Colors.surfaceMuted))
                .foregroundColor(SalomTheme.Colors.textPrimary)

            TextField(L.audience, text: $audience)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(SalomTheme.Colors.surfaceMuted))
                .foregroundColor(SalomTheme.Colors.textPrimary)

            HStack(spacing: 10) {
                Menu {
                    Button("O'zbekcha") { docLang = "uz" }
                    Button("Русский") { docLang = "ru" }
                    Button("English") { docLang = "en" }
                } label: { pickerLabel(langLabel(docLang)) }

                Menu {
                    ForEach(lengthOptions.filter { config == nil || $0 <= (config?.maxWords ?? 3000) }, id: \.self) { n in
                        Button("\(n) \(L.words)") { words = n }
                    }
                } label: { pickerLabel("\(words) \(L.words)") }
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle").font(.caption).foregroundColor(.red)
            }

            HStack {
                Text(config?.limit == -1 ? L.unlimited : (remaining.map { "\($0) \(L.remaining)" } ?? "")).font(.caption).foregroundColor(SalomTheme.Colors.textTertiary)
                Spacer()
                Button {
                    Task { await create() }
                } label: {
                    HStack(spacing: 8) {
                        if creating { ProgressView().tint(SalomTheme.Colors.onMedia).scaleEffect(0.8) } else { Image(systemName: "wand.and.stars") }
                        Text(creating ? L.creating : L.create).fontWeight(.semibold)
                    }
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(SalomTheme.Colors.onMedia).clipShape(Capsule())
                }
                .disabled(creating || topic.trimmingCharacters(in: .whitespaces).isEmpty || freeDailyReached)
                .opacity(creating || topic.trimmingCharacters(in: .whitespaces).isEmpty || freeDailyReached ? 0.5 : 1)
            }

            if freeDailyReached {
                HStack {
                    Text(L.freeDailyDone).font(.caption).foregroundColor(SalomTheme.Colors.textSecondary)
                    Spacer()
                    Button(L.upgrade) { showPaywall = true }.font(.caption.weight(.semibold)).foregroundColor(.orange)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.12)))
            }
        }
        .padding(16)
        .salomGlassCard(24)
    }

    private func pickerLabel(_ text: String) -> some View {
        HStack {
            Text(text).foregroundColor(SalomTheme.Colors.textPrimary).font(.system(size: 14))
            Spacer()
            Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(SalomTheme.Colors.textTertiary)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(SalomTheme.Colors.controlFill))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SalomTheme.Colors.border))
        .frame(maxWidth: .infinity)
    }

    private func langLabel(_ c: String) -> String {
        switch c { case "ru": return "Русский"; case "en": return "English"; default: return "O'zbekcha" }
    }

    // MARK: premium upsell (only when the feature is disabled entirely)

    private var premiumUpsell: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Premium", systemImage: "crown.fill")
                .font(.caption.weight(.bold)).foregroundColor(.orange)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color.orange.opacity(0.18)))
            Text(L.premiumTitle).font(.title2.weight(.bold)).foregroundColor(SalomTheme.Colors.textPrimary)
            Text(L.premiumDesc).font(.subheadline).foregroundColor(SalomTheme.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 8) {
                featureRow("doc.fill", "Word (DOCX) + PDF")
                featureRow("sparkles", L.editWithAI)
                featureRow("text.book.closed.fill", L.references)
            }
            .padding(.vertical, 4)
            Button { showPaywall = true } label: {
                Label(L.upgrade, systemImage: "crown.fill").fontWeight(.semibold)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(SalomTheme.Colors.onMedia).clipShape(Capsule())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color.orange.opacity(0.12), Color.purple.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.orange.opacity(0.3)))
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(.cyan).frame(width: 22)
            Text(text).font(.subheadline).foregroundColor(SalomTheme.Colors.textSecondary)
        }
    }

    // MARK: list

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L.myReferats, systemImage: "text.book.closed").font(.headline).foregroundColor(SalomTheme.Colors.textPrimary)
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text").font(.system(size: 36)).foregroundColor(SalomTheme.Colors.textTertiary)
                    Text(L.empty).foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
                .background(RoundedRectangle(cornerRadius: 20).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(SalomTheme.Colors.border))
            } else {
                ForEach(items) { r in row(r) }
            }
        }
    }

    private func row(_ r: ReferatSummary) -> some View {
        Button { openRef = ReferatRef(id: r.id) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color(hex: "#2563EB"), Color(hex: "#4F46E5")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 84, height: 52)
                    if r.status == "generating" { ProgressView().tint(.white).scaleEffect(0.7) }
                    else { Image(systemName: "text.book.closed.fill").foregroundColor(.white.opacity(0.9)) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.title.isEmpty ? "—" : r.title).font(.system(size: 15, weight: .semibold)).foregroundColor(SalomTheme.Colors.textPrimary).lineLimit(1)
                    Text(statusLabel(r)).font(.caption2).foregroundColor(SalomTheme.Colors.textTertiary)
                }
                Spacer()
                Button {
                    Task { try? await ReferatService.delete(r.id); await refreshList() }
                } label: { Image(systemName: "trash").font(.system(size: 13)).foregroundColor(SalomTheme.Colors.textTertiary).padding(8) }
            }
            .padding(10)
            .salomGlassCard(16, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func statusLabel(_ r: ReferatSummary) -> String {
        switch r.status {
        case "generating": return L.generating
        case "failed": return L.failed
        default: return "\(r.wordCount) \(L.words)"
        }
    }

    // MARK: data

    private func reload() async {
        loading = true
        docLang = L.docLang
        async let cfg = try? ReferatService.config()
        async let lst = try? ReferatService.list()
        let (c, l) = await (cfg, lst)
        config = c
        items = l ?? []
        loading = false
    }

    private func refreshList() async {
        if let l = try? await ReferatService.list() { items = l }
        if let c = try? await ReferatService.config() { config = c }
    }

    private func create() async {
        let t = topic.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !creating else { return }
        creating = true; errorText = nil
        do {
            let res = try await ReferatService.create(topic: t, language: docLang, targetWords: words, audience: audience.isEmpty ? nil : audience)
            Analytics.shared.track("referat_created", ["words": words, "language": docLang])
            creating = false
            topic = ""; audience = ""
            await refreshList()
            openRef = ReferatRef(id: res.id)
        } catch let APIError.server(status, message) {
            creating = false
            errorText = status == 403 ? L.freeDailyDone : (message ?? L.failed)
        } catch {
            creating = false
            errorText = error.localizedDescription
        }
    }
}
