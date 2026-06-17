//
//  DtmView.swift
//  Salom-Ai-iOS
//
//  Adaptive DTM test-prep (mirrors the web hub): subject grid → hub (level +
//  adaptive practice + sections + weak-area focus) → quiz → result. Real,
//  curated questions from the backend; the engine picks them adaptively.
//

import SwiftUI

struct DtmView: View {
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: DtmL { DtmL(languageCode) }

    private enum Stage { case subjects, hub, quiz, result }
    @State private var stage: Stage = .subjects
    @State private var subjects: [DtmSubject] = []
    @State private var loadingSubjects = true

    @State private var activeSubject = ""
    @State private var activeSubjectLabel = ""
    @State private var hub: DtmTopics?
    @State private var hubLoading = false

    @State private var questions: [DtmQuestion] = []
    @State private var idx = 0
    @State private var chosen: String?
    @State private var feedback: DtmAnswerResponse?
    @State private var score = 0
    @State private var checking = false
    @State private var levelLabel = ""

    @State private var loadingQuiz = false
    @State private var showPaywall = false
    @State private var comingSoon = false
    @State private var errorText: String?

    private let cyan = Color(hex: "#33E1ED")

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            content
        }
        .task {
            await loadSubjects()
            Analytics.shared.track("feature_opened", ["feature": "dtm"])
        }
        .fullScreenCover(isPresented: $showPaywall) { PaywallSheet() }
    }

    @ViewBuilder private var content: some View {
        switch stage {
        case .subjects: subjectsView
        case .hub: hubView
        case .quiz: quizView
        case .result: resultView
        }
    }

    // MARK: subjects
    private var subjectsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(L.title, L.subtitle, icon: "graduationcap.fill")
                if loadingSubjects {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 50)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(subjects) { s in
                            Button { Task { await openHub(s) } } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(s.label).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(2)
                                    Spacer(minLength: 0)
                                    Text("\(s.questionCount) \(L.questions)").font(.caption).foregroundColor(.white.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(16)
        }
    }

    // MARK: hub
    private var hubView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button { stage = .subjects } label: {
                    Label(L.back, systemImage: "chevron.left").font(.subheadline).foregroundColor(.white.opacity(0.6))
                }.buttonStyle(.plain)

                HStack {
                    Text(activeSubjectLabel).font(.title2.weight(.bold)).foregroundColor(.white)
                    Spacer()
                    if let h = hub {
                        Text("\(L.yourLevel): \(h.levelLabel)").font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(cyan.opacity(0.15))).foregroundColor(cyan)
                    }
                }

                if comingSoon { infoBanner(L.comingSoon) }
                if let e = errorText { infoBanner(e, color: .red) }

                // Adaptive practice CTA
                Button { Task { await startQuiz(topic: nil) } } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 48, height: 48)
                            if loadingQuiz { ProgressView().tint(.white) } else { Image(systemName: "sparkles").foregroundColor(.white).font(.system(size: 20)) }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.adaptive).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            Text(L.adaptiveHint).font(.caption).foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(cyan)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 22).fill(LinearGradient(colors: [cyan.opacity(0.15), Color.purple.opacity(0.12)], startPoint: .leading, endPoint: .trailing)))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(cyan.opacity(0.3)))
                }.buttonStyle(.plain).disabled(loadingQuiz)

                // Focus areas (weak topics)
                if let h = hub, h.topics.contains(where: { $0.seen > 0 }) {
                    Text(L.focus).font(.headline).foregroundColor(.white)
                    let weak = h.topics.filter { $0.seen > 0 }.sorted { $0.mastery < $1.mastery }.prefix(3)
                    FlowChips(items: weak.map { ($0.key, "\($0.topic) · \($0.mastery)%") }) { key in
                        Task { await startQuiz(topic: key.isEmpty ? nil : key) }
                    }
                }

                // Sections
                Text(L.sections).font(.headline).foregroundColor(.white)
                if hubLoading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity)
                } else if let h = hub, !h.topics.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(h.topics) { t in sectionRow(t) }
                    }
                } else {
                    infoBanner(L.comingSoon)
                }
            }.padding(16)
        }
    }

    private func sectionRow(_ t: DtmTopicStat) -> some View {
        Button { Task { await startQuiz(topic: t.key.isEmpty ? nil : t.key) } } label: {
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
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
        }.buttonStyle(.plain).disabled(loadingQuiz)
    }

    // MARK: quiz
    @ViewBuilder private var quizView: some View {
        if idx < questions.count {
            let q = questions[idx]
            VStack(spacing: 0) {
                HStack {
                    Button { stage = .hub } label: { Label(L.back, systemImage: "chevron.left").font(.caption).foregroundColor(.white.opacity(0.6)) }.buttonStyle(.plain)
                    Spacer()
                    if !levelLabel.isEmpty { Text(levelLabel).font(.caption2).foregroundColor(.white.opacity(0.5)).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Color.white.opacity(0.1))) }
                    Text("\(idx + 1) / \(questions.count)").font(.caption).foregroundColor(.white.opacity(0.6)).padding(.leading, 8)
                }.padding(.horizontal, 16).padding(.top, 12)

                ProgressView(value: Double(idx), total: Double(max(1, questions.count))).tint(cyan).padding(.horizontal, 16).padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let topic = q.topic, !topic.isEmpty {
                            Text(L.tr(topic).uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(cyan.opacity(0.8))
                        }
                        Text(L.tr(q.questionText)).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                        VStack(spacing: 10) {
                            ForEach(q.options, id: \.key) { o in optionRow(q: q, o: o) }
                        }
                        if let fb = feedback {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(fb.isCorrect ? L.correct : L.wrong).font(.subheadline.weight(.bold)).foregroundColor(fb.isCorrect ? .green : .red)
                                if let ex = fb.explanation, !ex.isEmpty { Text(L.tr(ex)).font(.footnote).foregroundColor(.white.opacity(0.85)) }
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill((fb.isCorrect ? Color.green : Color.red).opacity(0.12)))
                        }
                    }.padding(16)
                }

                Button { Task { feedback == nil ? await check() : next() } } label: {
                    Group {
                        if checking { ProgressView().tint(.white) }
                        else { Text(feedback == nil ? L.check : (idx + 1 >= questions.count ? L.finish : L.next)).fontWeight(.semibold) }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [cyan, .purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled((feedback == nil && chosen == nil) || checking)
                .opacity((feedback == nil && chosen == nil) ? 0.5 : 1)
                .padding(16)
            }
        } else {
            ProgressView().tint(.white)
        }
    }

    private func optionRow(q: DtmQuestion, o: DtmOption) -> some View {
        let isChosen = chosen == o.key
        let isCorrect = feedback != nil && o.key == feedback!.correctKey
        let isWrong = feedback != nil && isChosen && !feedback!.isCorrect
        return Button { if feedback == nil { chosen = o.key } } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(isCorrect ? Color.green : isWrong ? Color.red : Color.white.opacity(0.1)).frame(width: 28, height: 28)
                    if isCorrect { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white) }
                    else if isWrong { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white) }
                    else { Text(o.key).font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.7)) }
                }
                Text(L.tr(o.text)).font(.system(size: 15)).foregroundColor(.white).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(isChosen && feedback == nil ? 0.1 : 0.04)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isCorrect ? Color.green.opacity(0.6) : isWrong ? Color.red.opacity(0.6) : isChosen ? cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.5))
        }.buttonStyle(.plain).disabled(feedback != nil)
    }

    // MARK: result
    private var resultView: some View {
        let pct = questions.isEmpty ? 0 : Int(Double(score) / Double(questions.count) * 100)
        return VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(LinearGradient(colors: [cyan.opacity(0.2), Color.purple.opacity(0.2)], startPoint: .top, endPoint: .bottom)).frame(width: 120, height: 120)
                Text("\(pct)%").font(.system(size: 32, weight: .heavy)).foregroundColor(.white)
            }
            Text(L.result).font(.title3.weight(.bold)).foregroundColor(.white)
            Text("\(score) / \(questions.count)").foregroundColor(.white.opacity(0.6))
            VStack(spacing: 10) {
                Button { Task { await startQuiz(topic: nil) } } label: {
                    Label(L.again, systemImage: "arrow.clockwise").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [cyan, .purple], startPoint: .leading, endPoint: .trailing)).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Button { Task { await openHubByKey(activeSubject) } } label: {
                    Text(L.sections).fontWeight(.medium).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.white.opacity(0.1)).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }.padding(.horizontal, 24)
            Spacer()
        }.padding()
    }

    // MARK: helpers
    private func header(_ title: String, _ sub: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [cyan.opacity(0.2), Color.purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 48, height: 48)
                Image(systemName: icon).foregroundColor(cyan).font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.weight(.heavy)).foregroundColor(.white)
                Text(sub).font(.subheadline).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
    }
    private func infoBanner(_ text: String, color: Color = .cyan) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle").foregroundColor(color)
            Text(text).font(.footnote).foregroundColor(.white.opacity(0.8))
            Spacer()
        }.padding(12).background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }
    private func masteryColor(_ m: Int) -> Color { m >= 75 ? .green : m >= 50 ? .orange : m > 0 ? .red : .white.opacity(0.15) }

    // MARK: data
    private func loadSubjects() async {
        loadingSubjects = true
        subjects = (try? await DtmService.subjects()) ?? []
        loadingSubjects = false
    }
    private func openHub(_ s: DtmSubject) async {
        activeSubject = s.key; activeSubjectLabel = s.label
        await openHubByKey(s.key)
    }
    private func openHubByKey(_ key: String) async {
        errorText = nil; comingSoon = false; hub = nil; hubLoading = true; stage = .hub
        hub = try? await DtmService.topics(subject: key)
        if activeSubjectLabel.isEmpty, let l = subjects.first(where: { $0.key == key })?.label { activeSubjectLabel = l }
        hubLoading = false
    }
    private func startQuiz(topic: String?) async {
        loadingQuiz = true; errorText = nil; comingSoon = false
        defer { loadingQuiz = false }
        do {
            let data = try await DtmService.quiz(subject: activeSubject, topic: topic)
            if data.questions.isEmpty { comingSoon = true; stage = .hub; return }
            Analytics.shared.track("dtm_quiz_started", ["subject": activeSubject, "topic": topic ?? "adaptive"])
            levelLabel = data.levelLabel ?? ""
            questions = data.questions; idx = 0; score = 0; chosen = nil; feedback = nil
            stage = .quiz
        } catch let APIError.server(status, _) {
            if status == 403 { showPaywall = true; stage = .hub } else { errorText = L.comingSoon; stage = .hub }
        } catch { errorText = L.comingSoon; stage = .hub }
    }
    private func check() async {
        guard let c = chosen, !checking, idx < questions.count else { return }
        checking = true; defer { checking = false }
        if let res = try? await DtmService.answer(questionId: questions[idx].id, chosenKey: c) {
            feedback = res
            Analytics.shared.track("dtm_answered", ["subject": activeSubject, "correct": res.isCorrect])
            if res.isCorrect { score += 1 }
        }
    }
    private func next() {
        if idx + 1 >= questions.count { stage = .result; return }
        idx += 1; chosen = nil; feedback = nil
    }
}

// Simple wrapping chip row.
private struct FlowChips: View {
    let items: [(String, String)]
    let onTap: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.0) { item in
                Button { onTap(item.0) } label: {
                    Text(item.1).font(.caption).foregroundColor(.orange)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.orange.opacity(0.3)))
                }.buttonStyle(.plain)
            }
        }
    }
}
