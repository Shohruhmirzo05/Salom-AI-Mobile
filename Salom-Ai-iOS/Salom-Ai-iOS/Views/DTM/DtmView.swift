//
//  DtmView.swift
//  Salom-Ai-iOS
//
//  Adaptive DTM test-prep — native NavigationStack (typed path + destinations,
//  native back buttons), Liquid Glass surfaces on iOS 26+. Flow:
//  subjects (root) → hub (level + adaptive + sections) → quiz (self-contained,
//  shows result inline). The side-menu opens via the toolbar menu button.
//

import SwiftUI

enum DtmRoute: Hashable {
    case hub(subject: String, label: String)
    case quiz(subject: String, topic: String?)
}

// SF Symbol per subject for a native, scannable grid.
private let DTM_ICON: [String: String] = [
    "matematika": "function", "ona_tili": "book.closed.fill", "tarix": "building.columns.fill",
    "ingliz_tili": "character.book.closed.fill", "fizika": "atom", "kimyo": "flask.fill",
    "biologiya": "leaf.fill", "geografiya": "globe",
]

struct DtmView: View {
    var onMenu: () -> Void = {}
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: DtmL { DtmL(languageCode) }

    @State private var path = NavigationPath()
    @State private var subjects: [DtmSubject] = []
    @State private var loading = true

    private let cyan = Color(hex: "#33E1ED")

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                SalomTheme.Gradients.background.ignoresSafeArea()
                subjectsRoot
            }
            .navigationTitle("DTM")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GlassIconButton(systemName: "line.3.horizontal", size: 40) { onMenu() }
                }
            }
            .navigationDestination(for: DtmRoute.self) { route in
                switch route {
                case .hub(let subject, let label):
                    DtmHubView(subject: subject, label: label, path: $path)
                case .quiz(let subject, let topic):
                    DtmQuizView(subject: subject, topic: topic, path: $path)
                }
            }
        }
        .tint(cyan)
        .task { await loadSubjects(); Analytics.shared.track("feature_opened", ["feature": "dtm"]) }
    }

    private var subjectsRoot: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L.subtitle).font(.subheadline).foregroundColor(.white.opacity(0.6)).padding(.horizontal, 16)
                if loading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 60)
                } else if subjects.isEmpty {
                    errorRetry
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(subjects) { s in
                            Button { path.append(DtmRoute.hub(subject: s.key, label: s.label)) } label: {
                                subjectCard(s)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 16)
                }
            }.padding(.vertical, 8)
        }
    }

    private func subjectCard(_ s: DtmSubject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: DTM_ICON[s.key] ?? "graduationcap.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(cyan)
                .frame(width: 44, height: 44)
                .background(Circle().fill(cyan.opacity(0.14)))
            Spacer(minLength: 0)
            Text(s.label).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(2)
            Text(s.questionCount > 0 ? "\(s.questionCount) \(L.questions)" : L.comingSoon)
                .font(.caption).foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(14)
        .salomGlassCard(20, interactive: true)
    }

    private var errorRetry: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 34)).foregroundColor(.white.opacity(0.4))
            Text(L.loadError).font(.subheadline).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { Task { await loadSubjects() } } label: {
                Label(L.retry, systemImage: "arrow.clockwise").fontWeight(.semibold)
                    .padding(.horizontal, 20).padding(.vertical, 12)
            }.salomGlassButton(prominent: true).tint(cyan)
        }.frame(maxWidth: .infinity).padding(.top, 50)
    }

    private func loadSubjects() async {
        loading = true
        subjects = (try? await DtmService.subjects()) ?? []
        loading = false
    }
}
