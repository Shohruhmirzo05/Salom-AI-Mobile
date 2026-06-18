//
//  DtmHubView.swift
//  Salom-Ai-iOS
//
//  Subject hub: level badge, adaptive-practice CTA, weak-area focus, and
//  sections with mastery. Pushes the quiz onto the NavigationStack path.
//

import SwiftUI

struct DtmHubView: View {
    let subject: String
    let label: String
    @Binding var path: NavigationPath

    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: DtmL { DtmL(languageCode) }
    private let cyan = Color(hex: "#33E1ED")

    @State private var hub: DtmTopics?
    @State private var loading = true

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let h = hub {
                        HStack {
                            Text("\(L.yourLevel): \(h.levelLabel)")
                                .font(.caption.weight(.semibold)).foregroundColor(cyan)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .salomGlassPill()
                            Spacer()
                        }
                    }

                    // Adaptive practice — primary CTA
                    Button { path.append(DtmRoute.quiz(subject: subject, topic: nil)) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles").font(.system(size: 20)).foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(LinearGradient(colors: [cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L.adaptive).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                Text(L.adaptiveHint).font(.caption).foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(cyan)
                        }.padding(16).salomGlassCard(22, interactive: true)
                    }.buttonStyle(.plain)

                    // Focus areas (weak topics)
                    if let h = hub, h.topics.contains(where: { $0.seen > 0 }) {
                        Text(L.focus).font(.headline).foregroundColor(.white)
                        let weak = Array(h.topics.filter { $0.seen > 0 }.sorted { $0.mastery < $1.mastery }.prefix(3))
                        ForEach(weak) { t in
                            Button { path.append(DtmRoute.quiz(subject: subject, topic: t.key.isEmpty ? nil : t.key)) } label: {
                                Text("\(L.tr(t.topic)) · \(t.mastery)%").font(.caption.weight(.medium)).foregroundColor(.orange)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Color.orange.opacity(0.12)))
                                    .overlay(Capsule().stroke(Color.orange.opacity(0.3)))
                            }.buttonStyle(.plain)
                        }
                    }

                    Text(L.sections).font(.headline).foregroundColor(.white)
                    if loading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity)
                    } else if let h = hub, !h.topics.isEmpty {
                        ForEach(h.topics) { t in sectionRow(t) }
                    } else {
                        infoBanner(L.comingSoon)
                    }
                }.padding(16)
            }
        }
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func sectionRow(_ t: DtmTopicStat) -> some View {
        Button { path.append(DtmRoute.quiz(subject: subject, topic: t.key.isEmpty ? nil : t.key)) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L.tr(t.topic)).font(.system(size: 15, weight: .medium)).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Text(t.seen > 0 ? "\(t.mastery)% \(L.mastery)" : L.notStarted).font(.caption).foregroundColor(.white.opacity(0.5))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                        Capsule().fill(masteryColor(t.mastery)).frame(width: max(t.seen > 0 ? 8 : 0, geo.size.width * CGFloat(t.mastery) / 100), height: 6)
                    }
                }.frame(height: 6)
                Text("\(t.questionCount) \(L.questions)").font(.system(size: 11)).foregroundColor(.white.opacity(0.35))
            }
            .padding(14).salomGlassCard(16)
        }.buttonStyle(.plain)
    }

    private func infoBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle").foregroundColor(cyan)
            Text(text).font(.footnote).foregroundColor(.white.opacity(0.8)); Spacer()
        }.padding(14).salomGlassCard(14)
    }

    private func masteryColor(_ m: Int) -> Color { m >= 75 ? .green : m >= 50 ? .orange : m > 0 ? .red : .white.opacity(0.15) }

    private func load() async {
        loading = true
        hub = try? await DtmService.topics(subject: subject)
        loading = false
    }
}
