//
//  WorkListView.swift
//  Salom-Ai-iOS
//
//  "Ish" hub — segment tabs + task grid + recent documents. Work is paid-only:
//  free/locked users see an upsell and hit the paywall on create. Mirrors
//  PresentationsListView.swift.
//

import SwiftUI

// Lucide icon name (from backend) → 3D icon slug (self-hosted on web at /icons3d).
private let ICON3D_BY_LUCIDE: [String: String] = [
    "file-text": "doc", "scroll-text": "contract", "briefcase": "briefcase", "receipt": "receipt",
    "grid-2x2": "swot", "bar-chart-3": "report", "mail": "mail", "clipboard-list": "clipboard",
    "send": "send", "wallet": "wallet", "graduation-cap": "grad", "list-checks": "checklist",
    "user-round": "user", "landmark": "bank", "table": "ledger", "file-check": "filecheck",
]

/// Glossy 3D icon loaded from the web asset host (same set the web app uses).
struct Icon3DView: View {
    let slug: String
    var size: CGFloat = 44
    init(slug: String, size: CGFloat = 44) { self.slug = slug; self.size = size }
    init(lucide: String, size: CGFloat = 44) { self.slug = ICON3D_BY_LUCIDE[lucide] ?? "doc"; self.size = size }
    var body: some View {
        AsyncImage(url: URL(string: "https://salom-ai.uz/icons3d/\(slug).webp")) { img in
            img.resizable().scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: 10).fill(SalomTheme.Colors.surfaceMuted)
        }
        .frame(width: size, height: size)
    }
}

private struct IntId: Identifiable { let id: Int }

struct WorkListView: View {
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"

    @State private var segments: [WorkSegment] = []
    @State private var tasks: [WorkTask] = []
    @State private var access: WorkAccess?
    @State private var recent: [WorkDoc] = []
    @State private var selectedSegment: String = "business"
    @State private var loading = true

    @State private var activeTask: WorkTask?
    @State private var activeDoc: IntId?
    @State private var showPaywall = false

    private var L: IshL { IshL(languageCode) }

    private var visibleTasks: [WorkTask] { tasks.filter { $0.segment == selectedSegment } }

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            if loading {
                ProgressView().tint(SalomTheme.Colors.accentPrimary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if access?.mode == "locked" { lockedBanner }
                        else if let a = access, a.monthlyLimit > 0 {
                            Text("\(L.thisMonth): \(a.monthlyUsed)/\(a.monthlyLimit)")
                                .font(.system(size: 12)).foregroundColor(SalomTheme.Colors.textTertiary)
                        }
                        segmentTabs
                        taskGrid
                        if !recent.isEmpty { recentSection }
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await load() }
        .fullScreenCover(item: $activeTask, onDismiss: { Task { await load() } }) { task in
            WorkDetailView(task: task, docLang: L.docLang)
        }
        .fullScreenCover(item: $activeDoc, onDismiss: { Task { await load() } }) { d in
            WorkDetailView(docId: d.id, docLang: L.docLang)
        }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet(context: .officeFirstValue, source: "ios_work_hub") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.title).font(.system(size: 24, weight: .bold)).foregroundColor(SalomTheme.Colors.textPrimary)
            Text(L.subtitle).font(.system(size: 14)).foregroundColor(SalomTheme.Colors.textSecondary)
        }
    }

    private var lockedBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.lockedTitle).font(.system(size: 15, weight: .semibold)).foregroundColor(SalomTheme.Colors.textPrimary)
            Text(L.lockedDesc).font(.system(size: 13)).foregroundColor(SalomTheme.Colors.textSecondary)
            Button { showPaywall = true } label: {
                Text(L.upgrade).font(.system(size: 14, weight: .semibold)).foregroundColor(SalomTheme.Colors.onAccent)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(LinearGradient(colors: [Color(SalomTheme.Colors.accentSecondary), Color(SalomTheme.Colors.accentPrimary)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.yellow.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.yellow.opacity(0.22), lineWidth: 1))
    }

    private var segmentTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(segments) { s in
                    let on = selectedSegment == s.id
                    Button { selectedSegment = s.id } label: {
                        Text(s.label.pick(languageCode))
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(on ? SalomTheme.Colors.textPrimary : SalomTheme.Colors.textSecondary)
                            .padding(.horizontal, 15).padding(.vertical, 8)
                            .background(Capsule().fill(on ? SalomTheme.Colors.surface : SalomTheme.Colors.controlFill))
                            .overlay(Capsule().stroke(SalomTheme.Colors.border))
                    }
                }
            }
        }
    }

    private var taskGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            ForEach(visibleTasks) { task in
                Button { activeTask = task } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Icon3DView(lucide: task.icon, size: 40)
                            Spacer()
                            Text(task.output == "xlsx" ? "Excel" : "Word")
                                .font(.system(size: 9, weight: .semibold)).foregroundColor(SalomTheme.Colors.textTertiary)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(SalomTheme.Colors.border))
                        }
                        Text(task.title.pick(languageCode))
                            .font(.system(size: 14.5, weight: .semibold)).foregroundColor(SalomTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                        Text(task.subtitle.pick(languageCode))
                            .font(.system(size: 11.5)).foregroundColor(SalomTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                    }
                    .padding(14).frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(SalomTheme.Colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(SalomTheme.Colors.border))
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.recent.uppercased()).font(.system(size: 12, weight: .semibold))
                .foregroundColor(SalomTheme.Colors.textTertiary).tracking(0.5)
            ForEach(recent.prefix(8)) { w in
                Button { activeDoc = IntId(id: w.id) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: w.outputFormat == "xlsx" ? "tablecells" : "doc.text")
                            .foregroundColor(SalomTheme.Colors.textTertiary).font(.system(size: 14))
                        Text(w.title).font(.system(size: 14)).foregroundColor(SalomTheme.Colors.textPrimary).lineLimit(1)
                        Spacer()
                        if w.status == "generating" { Text(L.creating).font(.system(size: 11)).foregroundColor(.orange) }
                        else if w.status == "failed" { Text(L.failed).font(.system(size: 11)).foregroundColor(.red) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(SalomTheme.Colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(SalomTheme.Colors.border))
                }
            }
        }
    }

    private func load() async {
        do {
            let res = try await WorkService.tasks()
            let list = (try? await WorkService.list()) ?? []
            await MainActor.run {
                self.segments = res.segments
                self.tasks = res.tasks
                self.access = res.access
                self.recent = list
                if !res.segments.contains(where: { $0.id == selectedSegment }) {
                    self.selectedSegment = res.segments.first?.id ?? "business"
                }
                self.loading = false
            }
        } catch {
            await MainActor.run { self.loading = false }
        }
    }
}
