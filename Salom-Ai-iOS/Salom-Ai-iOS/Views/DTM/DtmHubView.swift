//
//  DtmHubView.swift
//  Salom-Ai-iOS
//
//  Level selection: pick Boshlang'ich / O'rta / Yuqori (each its own question set
//  with a live count) → pushes the quiz onto the NavigationStack. Replaces the old
//  adaptive "hub" that confused users. Mirrors the web DTM level cards.
//

import SwiftUI

struct DtmLevelsView: View {
    let subject: String
    let label: String
    @Binding var path: NavigationPath

    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: DtmL { DtmL(languageCode) }
    private let cyan = Color(hex: "#33E1ED")

    @State private var levels: [DtmLevel] = []
    @State private var loading = true

    // Accent gradient + a 1/2/3 step so difficulty reads at a glance.
    private func meta(_ key: String) -> (grad: [Color], step: Int) {
        switch key {
        case "easy": return ([Color(hex: "#38BDF8"), Color(hex: "#22D3EE")], 1)
        case "hard": return ([Color(hex: "#34D399"), Color(hex: "#10B981")], 3)
        default: return ([Color(hex: "#FBBF24"), Color(hex: "#FB923C")], 2)
        }
    }

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L.levelHint).font(.subheadline).foregroundColor(.white.opacity(0.6))
                    if loading {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 44)
                    } else if levels.isEmpty {
                        infoBanner(L.comingSoon)
                    } else {
                        ForEach(levels) { lv in levelCard(lv) }
                    }
                }.padding(16)
            }
        }
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func levelCard(_ lv: DtmLevel) -> some View {
        let m = meta(lv.key)
        let empty = lv.count == 0
        return Button {
            guard !empty else { return }
            path.append(DtmRoute.quiz(subject: subject, difficulty: lv.key, levelLabel: L.levelLabel(lv.key)))
        } label: {
            HStack(spacing: 14) {
                Text("\(m.step)")
                    .font(.system(size: 20, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(LinearGradient(colors: m.grad, startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L.levelLabel(lv.key)).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Text("\(L.levelDesc(lv.key)) · \(empty ? L.comingSoon : "\(lv.count) \(L.questions)")")
                        .font(.caption).foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .salomGlassCard(20, interactive: !empty)
            .opacity(empty ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(empty)
    }

    private func infoBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle").foregroundColor(cyan)
            Text(text).font(.footnote).foregroundColor(.white.opacity(0.8)); Spacer()
        }.padding(14).salomGlassCard(14)
    }

    private func load() async {
        loading = true
        levels = (try? await DtmService.levels(subject: subject))?.levels ?? []
        loading = false
    }
}
