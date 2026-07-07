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
    let lucide: String
    var size: CGFloat = 44
    var body: some View {
        let slug = ICON3D_BY_LUCIDE[lucide] ?? "doc"
        AsyncImage(url: URL(string: "https://salom-ai.uz/icons3d/\(slug).webp")) { img in
            img.resizable().scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06))
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
                ProgressView().tint(.white.opacity(0.6))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if access?.mode == "locked" { lockedBanner }
                        else if let a = access, a.monthlyLimit > 0 {
                            Text("\(L.thisMonth): \(a.monthlyUsed)/\(a.monthlyLimit)")
                                .font(.system(size: 12)).foregroundColor(.white.opacity(0.45))
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
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L.title).font(.system(size: 24, weight: .bold)).foregroundColor(.white)
            Text(L.subtitle).font(.system(size: 14)).foregroundColor(.white.opacity(0.55))
        }
    }

    private var lockedBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.lockedTitle).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            Text(L.lockedDesc).font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
            Button { showPaywall = true } label: {
                Text(L.upgrade).font(.system(size: 14, weight: .semibold)).foregroundColor(.black)
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
                            .foregroundColor(on ? .black : .white.opacity(0.7))
                            .padding(.horizontal, 15).padding(.vertical, 8)
                            .background(Capsule().fill(on ? Color.white : Color.white.opacity(0.06)))
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
                                .font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.35))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.12)))
                        }
                        Text(task.title.pick(languageCode))
                            .font(.system(size: 14.5, weight: .semibold)).foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                        Text(task.subtitle.pick(languageCode))
                            .font(.system(size: 11.5)).foregroundColor(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.leading)
                    }
                    .padding(14).frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.07)))
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.recent.uppercased()).font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4)).tracking(0.5)
            ForEach(recent.prefix(8)) { w in
                Button { activeDoc = IntId(id: w.id) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: w.outputFormat == "xlsx" ? "tablecells" : "doc.text")
                            .foregroundColor(.white.opacity(0.4)).font(.system(size: 14))
                        Text(w.title).font(.system(size: 14)).foregroundColor(.white).lineLimit(1)
                        Spacer()
                        if w.status == "generating" { Text(L.creating).font(.system(size: 11)).foregroundColor(.orange) }
                        else if w.status == "failed" { Text(L.failed).font(.system(size: 11)).foregroundColor(.red) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
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
