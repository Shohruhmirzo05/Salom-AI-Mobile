//
//  PresentationsListView.swift
//  Salom-Ai-iOS
//
//  Hub for the AI presentation builder: create form (subscription-gated),
//  paywall upsell for free users, and the list of the user's decks.
//

import SwiftUI

private struct PresoRef: Identifiable { let id: Int }

struct PresentationsListView: View {
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: PresoL { PresoL(languageCode) }

    @State private var config: PresoConfig?
    @State private var decks: [PresentationSummary] = []
    @State private var loading = true

    @State private var topic = ""
    @State private var audience = ""
    @State private var slideCount = 10
    @State private var theme = "midnight"
    @State private var deckLang = "uz"
    @State private var creating = false
    @State private var errorText: String?

    @State private var openRef: PresoRef?
    @State private var showPaywall = false

    private let slideOptions = [6, 8, 10, 12, 15]

    private var isPremiumLocked: Bool { config?.limit == 0 }
    private var limitReached: Bool { if let c = config { return c.limit > 0 && c.used >= c.limit }; return false }
    private var remaining: Int? { if let c = config, c.limit > 0 { return max(0, c.limit - c.used) }; return nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if loading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 60)
                } else if isPremiumLocked {
                    premiumUpsell
                } else {
                    createCard
                }
                decksSection
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await reload(); Analytics.shared.track("feature_opened", ["feature": "presentations"]) }
        .fullScreenCover(item: $openRef, onDismiss: { Task { await refreshList() } }) { ref in
            PresentationEditorView(presentationId: ref.id)
        }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet() }
    }

    // MARK: create

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(L.topicPlaceholder, text: $topic, axis: .vertical)
                .lineLimit(2...5)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
                .foregroundColor(.white)

            TextField(L.audience, text: $audience)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                .foregroundColor(.white)

            HStack(spacing: 10) {
                Menu {
                    Button("O'zbekcha") { deckLang = "uz" }
                    Button("Русский") { deckLang = "ru" }
                    Button("English") { deckLang = "en" }
                } label: { pickerLabel(langLabel(deckLang)) }

                Menu {
                    ForEach(slideOptions.filter { config == nil || $0 <= (config?.maxSlides ?? 20) }, id: \.self) { n in
                        Button("\(n) \(L.slides)") { slideCount = n }
                    }
                } label: { pickerLabel("\(slideCount) \(L.slides)") }
            }

            // theme swatches — horizontally scrollable so they never force the
            // card wider than the screen (which previously broke all padding).
            VStack(alignment: .leading, spacing: 8) {
                Text(L.theme.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(config?.themes ?? []) { th in
                            Button { theme = th.id } label: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DeckStyles.style(th.id).gradient)
                                    .frame(width: 54, height: 40)
                                    .overlay(alignment: .bottomTrailing) {
                                        Circle().fill(DeckStyles.style(th.id).accent).frame(width: 10, height: 10).padding(5)
                                    }
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme == th.id ? Color(hex: "#33E1ED") : Color.white.opacity(0.12), lineWidth: theme == th.id ? 2.5 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle").font(.caption).foregroundColor(.red)
            }

            HStack {
                Text(config?.limit == -1 ? L.unlimited : (remaining.map { "\($0) \(L.remaining)" } ?? "")).font(.caption).foregroundColor(.white.opacity(0.4))
                Spacer()
                Button {
                    Task { await create() }
                } label: {
                    HStack(spacing: 8) {
                        if creating { ProgressView().tint(.white).scaleEffect(0.8) } else { Image(systemName: "wand.and.stars") }
                        Text(creating ? L.creating : L.create).fontWeight(.semibold)
                    }
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white).clipShape(Capsule())
                }
                .disabled(creating || topic.trimmingCharacters(in: .whitespaces).isEmpty || limitReached)
                .opacity(creating || topic.trimmingCharacters(in: .whitespaces).isEmpty || limitReached ? 0.5 : 1)
            }

            if limitReached {
                HStack {
                    Text(L.limitReached).font(.caption).foregroundColor(.white.opacity(0.8))
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
            Text(text).foregroundColor(.white).font(.system(size: 14))
            Spacer()
            Image(systemName: "chevron.down").font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        .frame(maxWidth: .infinity)
    }

    private func langLabel(_ c: String) -> String {
        switch c { case "ru": return "Русский"; case "en": return "English"; default: return "O'zbekcha" }
    }

    // MARK: premium upsell

    private var premiumUpsell: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Premium", systemImage: "crown.fill")
                .font(.caption.weight(.bold)).foregroundColor(.orange)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color.orange.opacity(0.18)))
            Text(L.premiumTitle).font(.title2.weight(.bold)).foregroundColor(.white)
            Text(L.premiumDesc).font(.subheadline).foregroundColor(.white.opacity(0.6))
            VStack(alignment: .leading, spacing: 8) {
                featureRow("doc.fill", "PowerPoint (PPTX) + PDF")
                featureRow("sparkles", L.editWithAI)
                featureRow("photo.fill", "Premium stock images")
            }
            .padding(.vertical, 4)
            Button { showPaywall = true } label: {
                Label(L.upgrade, systemImage: "crown.fill").fontWeight(.semibold)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white).clipShape(Capsule())
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
            Text(text).font(.subheadline).foregroundColor(.white.opacity(0.75))
        }
    }

    // MARK: decks list

    private var decksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L.myDecks, systemImage: "sparkles").font(.headline).foregroundColor(.white)
            if decks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.on.rectangle.angled").font(.system(size: 36)).foregroundColor(.white.opacity(0.25))
                    Text(L.empty).foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
                .background(RoundedRectangle(cornerRadius: 20).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])).foregroundColor(.white.opacity(0.1)))
            } else {
                ForEach(decks) { d in deckRow(d) }
            }
        }
    }

    private func deckRow(_ d: PresentationSummary) -> some View {
        Button { openRef = PresoRef(id: d.id) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(DeckStyles.style(d.theme).gradient).frame(width: 84, height: 52)
                    if d.status == "generating" { ProgressView().tint(DeckStyles.style(d.theme).accent).scaleEffect(0.7) }
                    else { Image(systemName: "rectangle.3.group.fill").foregroundColor(DeckStyles.style(d.theme).accent) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(d.title.isEmpty ? "—" : d.title).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                    Text(statusLabel(d)).font(.caption2).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Button {
                    Task { try? await PresentationService.delete(d.id); await refreshList() }
                } label: { Image(systemName: "trash").font(.system(size: 13)).foregroundColor(.white.opacity(0.4)).padding(8) }
            }
            .padding(10)
            .salomGlassCard(16, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func statusLabel(_ d: PresentationSummary) -> String {
        switch d.status {
        case "generating": return L.generating
        case "failed": return L.failed
        default: return "\(d.slideCount) \(L.slides)"
        }
    }

    // MARK: data

    private func reload() async {
        loading = true
        deckLang = L.deckLang
        async let cfg = try? PresentationService.config()
        async let lst = try? PresentationService.list()
        let (c, l) = await (cfg, lst)
        config = c
        if let dt = c?.defaultTheme { theme = dt }
        decks = l ?? []
        loading = false
    }

    private func refreshList() async {
        if let l = try? await PresentationService.list() { decks = l }
        if let c = try? await PresentationService.config() { config = c }
    }

    private func create() async {
        let t = topic.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !creating else { return }
        creating = true; errorText = nil
        do {
            let res = try await PresentationService.create(topic: t, language: deckLang, slideCount: slideCount, theme: theme, audience: audience.isEmpty ? nil : audience)
            Analytics.shared.track("presentation_created", ["slides": slideCount, "language": deckLang])
            creating = false
            topic = ""; audience = ""
            await refreshList()
            openRef = PresoRef(id: res.id)
        } catch let APIError.server(status, message) {
            creating = false
            errorText = status == 403 ? L.limitReached : (message ?? L.failed)
        } catch {
            creating = false
            errorText = error.localizedDescription
        }
    }
}
