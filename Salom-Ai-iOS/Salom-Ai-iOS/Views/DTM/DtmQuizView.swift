//
//  DtmQuizView.swift
//  Salom-Ai-iOS
//
//  Self-contained quiz: loads an adaptive quiz, scores answers, shows the result
//  inline. Native back (NavigationStack) returns to the hub; "Sections" pops too.
//  Free daily limit → PaywallSheet.
//

import SwiftUI

struct DtmQuizView: View {
    let subject: String
    let difficulty: String
    let levelLabel: String
    @Binding var path: NavigationPath

    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"
    private var L: DtmL { DtmL(languageCode) }
    private let cyan = Color(hex: "#33E1ED")

    @State private var questions: [DtmQuestion] = []
    @State private var idx = 0
    @State private var chosen: String?
    @State private var feedback: DtmAnswerResponse?
    @State private var score = 0
    @State private var checking = false
    @State private var loading = true
    @State private var showResult = false
    @State private var showPaywall = false
    @State private var comingSoon = false

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            if loading {
                ProgressView().tint(SalomTheme.Colors.accentPrimary)
            } else if comingSoon {
                infoState(L.comingSoon)
            } else if showResult {
                resultView
            } else if idx < questions.count {
                quizView(questions[idx])
            } else {
                infoState(L.comingSoon)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !levelLabel.isEmpty && !showResult {
                    Text("\(idx + 1) / \(questions.count) · \(levelLabel)").font(.caption).foregroundColor(SalomTheme.Colors.textSecondary)
                }
            }
        }
        .task { await loadQuiz() }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: { if path.count > 0 { path.removeLast() } }) {
            PaywallSheet(context: .dtmDailyLimit, source: "ios_dtm_limit")
        }
    }

    // MARK: quiz
    private func quizView(_ q: DtmQuestion) -> some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(idx), total: Double(max(1, questions.count))).tint(cyan).padding(.horizontal, 16).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let t = q.topic, !t.isEmpty {
                        Text(L.tr(t).uppercased()).font(.system(size: 11, weight: .semibold)).foregroundColor(cyan.opacity(0.8))
                    }
                    Text(L.tr(q.questionText)).font(.system(size: 18, weight: .semibold)).foregroundColor(SalomTheme.Colors.textPrimary)
                    VStack(spacing: 10) { ForEach(q.options, id: \.key) { o in optionRow(q, o) } }
                    if let fb = feedback {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(fb.isCorrect ? L.correct : L.wrong).font(.subheadline.weight(.bold)).foregroundColor(fb.isCorrect ? .green : .red)
                            if let ex = fb.explanation, !ex.isEmpty { Text(L.tr(ex)).font(.footnote).foregroundColor(SalomTheme.Colors.textSecondary) }
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).salomGlassCard(16)
                    }
                }.padding(16)
            }
            Button { Task { feedback == nil ? await check() : next() } } label: {
                Group {
                    if checking { ProgressView().tint(SalomTheme.Colors.onMedia) }
                    else { Text(feedback == nil ? L.check : (idx + 1 >= questions.count ? L.finish : L.next)).fontWeight(.semibold) }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(LinearGradient(colors: [cyan, .purple], startPoint: .leading, endPoint: .trailing))
                .foregroundColor(SalomTheme.Colors.onMedia).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled((feedback == nil && chosen == nil) || checking)
            .opacity((feedback == nil && chosen == nil) ? 0.5 : 1)
            .padding(16)
        }
    }

    private func optionRow(_ q: DtmQuestion, _ o: DtmOption) -> some View {
        let isChosen = chosen == o.key
        let isCorrect = feedback != nil && o.key == feedback!.correctKey
        let isWrong = feedback != nil && isChosen && !feedback!.isCorrect
        return Button { if feedback == nil { chosen = o.key } } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(isCorrect ? Color.green : isWrong ? Color.red : SalomTheme.Colors.surfaceMuted).frame(width: 28, height: 28)
                    if isCorrect { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(SalomTheme.Colors.onMedia) }
                    else if isWrong { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(SalomTheme.Colors.onMedia) }
                    else { Text(o.key).font(.system(size: 13, weight: .bold)).foregroundColor(SalomTheme.Colors.textSecondary) }
                }
                Text(L.tr(o.text)).font(.system(size: 15)).foregroundColor(SalomTheme.Colors.textPrimary).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(isChosen && feedback == nil ? SalomTheme.Colors.controlFillActive : SalomTheme.Colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isCorrect ? Color.green.opacity(0.6) : isWrong ? Color.red.opacity(0.6) : isChosen ? cyan.opacity(0.6) : SalomTheme.Colors.border, lineWidth: 1.5))
        }.buttonStyle(.plain).disabled(feedback != nil)
    }

    // MARK: result
    private var resultView: some View {
        let pct = questions.isEmpty ? 0 : Int(Double(score) / Double(questions.count) * 100)
        return VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(LinearGradient(colors: [cyan.opacity(0.2), Color.purple.opacity(0.2)], startPoint: .top, endPoint: .bottom)).frame(width: 120, height: 120)
                Text("\(pct)%").font(.system(size: 32, weight: .heavy)).foregroundColor(SalomTheme.Colors.textPrimary)
            }
            Text(L.result).font(.title3.weight(.bold)).foregroundColor(SalomTheme.Colors.textPrimary)
            Text("\(score) / \(questions.count)").foregroundColor(SalomTheme.Colors.textSecondary)
            VStack(spacing: 10) {
                Button { Task { await loadQuiz() } } label: {
                    Label(L.again, systemImage: "arrow.clockwise").fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(LinearGradient(colors: [cyan, .purple], startPoint: .leading, endPoint: .trailing)).foregroundColor(SalomTheme.Colors.onMedia).clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Button { if path.count > 0 { path.removeLast() } } label: {
                    Text(L.chooseLevel).fontWeight(.medium).frame(maxWidth: .infinity).padding(.vertical, 14).foregroundColor(SalomTheme.Colors.textPrimary)
                        .salomGlassCard(16, interactive: true)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 24)
            Spacer()
        }.padding()
    }

    private func infoState(_ text: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "hourglass").font(.system(size: 34)).foregroundColor(SalomTheme.Colors.textTertiary)
            Text(text).font(.subheadline).foregroundColor(SalomTheme.Colors.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 32)
        }
    }

    // MARK: data
    private func loadQuiz() async {
        loading = true; comingSoon = false; showResult = false
        defer { loading = false }
        do {
            let data = try await DtmService.quiz(subject: subject, difficulty: difficulty)
            if data.questions.isEmpty { comingSoon = true; return }
            Analytics.shared.track("dtm_quiz_started", ["subject": subject, "level": difficulty])
            questions = data.questions; idx = 0; score = 0; chosen = nil; feedback = nil
        } catch let APIError.server(status, _) where status == 403 {
            showPaywall = true
        } catch {
            comingSoon = true
        }
    }

    private func check() async {
        guard let c = chosen, !checking, idx < questions.count else { return }
        checking = true; defer { checking = false }
        if let res = try? await DtmService.answer(questionId: questions[idx].id, chosenKey: c) {
            feedback = res
            Analytics.shared.track("dtm_answered", ["subject": subject, "correct": res.isCorrect])
            if res.isCorrect { score += 1 }
        }
    }

    private func next() {
        if idx + 1 >= questions.count { showResult = true; return }
        idx += 1; chosen = nil; feedback = nil
    }
}
