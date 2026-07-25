//
//  RealtimeVoiceView.swift
//  Salom-Ai-iOS
//
//  Created by Salom AI on 27/11/25.
//

import SwiftUI

struct RealtimeVoiceView: View {
    @StateObject private var viewModel = RealtimeVoiceViewModel()
    @Environment(\.dismiss) var dismiss
    @AppStorage(AppStorageKeys.preferredLanguageCode)
    private var languageCode: String = "uz"
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showBlockAlert = false
    @State private var didRunPreflight = false
    private let previewState: RealtimeVoiceState?
    var onDismiss: (() -> Void)?

    init(
        previewState: RealtimeVoiceState? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.previewState = previewState
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            SalomTheme.Gradients.background.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button {
                        print("❌ [RealtimeUI] Close button tapped")
                        viewModel.disconnect()
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                            .padding(12)
                            .background(Circle().fill(SalomTheme.Colors.surfaceMuted))
                            .overlay(Circle().stroke(SalomTheme.Colors.border))
                    }
                    
                    Spacer()
                    
                    // Language Indicator
                    HStack(spacing: 6) {
                        Text(viewModel.currentLanguageFlag)
                            .font(.system(size: 24))
                        Text(viewModel.currentLanguageName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(SalomTheme.Colors.surfaceMuted))
                    .overlay(Capsule().stroke(SalomTheme.Colors.border))
                    
                    Spacer()
                    
                    Button {
                        viewModel.stopAudio()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(SalomTheme.Colors.textPrimary)
                            .padding(12)
                            .background(Circle().fill(SalomTheme.Colors.surfaceMuted))
                            .overlay(Circle().stroke(SalomTheme.Colors.border))
                    }
                }
                .padding()
                
                Spacer()
                
                // Visualizer
                RealtimeVisualizerView(
                    audioLevel: previewState == nil ? viewModel.audioLevel : 0.34,
                    state: displayedVoiceState
                )
                
                Spacer()
                
                // Status Text
                VStack(spacing: 8) {
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(SalomTheme.Colors.textPrimary)
                    
                    // Beta Disclaimer
                    HStack(spacing: 6) {
                        Text("Beta")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow)
                            .cornerRadius(4)

                        Text(copy(
                            "Sinov rejimi — xatolar bo‘lishi mumkin",
                            "Синов режими — хатолар бўлиши мумкин",
                            "Тестовый режим — возможны ошибки",
                            "Beta mode — errors may occur"
                        ))
                            .font(.caption)
                            .foregroundColor(SalomTheme.Colors.textSecondary)
                    }
                }
                .padding(.bottom, 40)
                
                // Controls
                HStack(spacing: 40) {
                    Button {
                        viewModel.isMuted.toggle()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.title2)
                                .foregroundColor(viewModel.isMuted ? .red : SalomTheme.Colors.textPrimary)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(SalomTheme.Colors.surfaceMuted))
                                .overlay(Circle().stroke(SalomTheme.Colors.border))
                            
                            Text(viewModel.isMuted
                                 ? copy("Ovoz yoqish", "Овозни ёқиш", "Включить микрофон", "Unmute")
                                 : copy("Ovoz o‘chirish", "Овозни ўчириш", "Выключить микрофон", "Mute"))
                                .font(.caption)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                    }
                    
                    Button {
                        print("❌ [RealtimeUI] Hangup button tapped")
                        viewModel.disconnect()
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            dismiss()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.down.fill")
                                .font(.title2)
                                .foregroundColor(SalomTheme.Colors.onMedia)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.red))
                            
                            Text(copy("Tugatish", "Тугатиш", "Завершить", "End"))
                                .font(.caption)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            guard previewState == nil else { return }
            // Preflight subscription check BEFORE opening any WS so a blocked
            // user goes straight to the paywall instead of seeing a brief
            // "connecting..." then a hard close.
            guard !didRunPreflight else { return }
            didRunPreflight = true
            Task {
                let allowed = await viewModel.preflight()
                if allowed {
                    viewModel.connect()
                } else {
                    // Surface the reason (limit reached + reset date OR plan-doesn't-include)
                    // and queue the paywall to auto-open on dismiss.
                    showBlockAlert = true
                }
            }
        }
        .alert("Ovozli rejim mavjud emas", isPresented: $showBlockAlert) {
            Button("Rejani yangilash") {
                showPaywall = true
            }
            Button("Yopish", role: .cancel) {
                if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
            }
        } message: {
            Text(viewModel.blockedReason ?? "Ushbu hisobda real-vaqt ovozli suhbatlar mavjud emas.")
        }
        // Mid-session quota refusal: backend closes the WS with a 4xxx code,
        // ViewModel populates `blockedReason`, we surface the same alert as
        // the preflight-blocked path — no more "stuck on Connecting".
        .onChange(of: viewModel.blockedReason) { _, newReason in
            if newReason != nil && !showBlockAlert && !showPaywall {
                viewModel.disconnect()  // make sure nothing is still trying
                showBlockAlert = true
            }
        }
        .onDisappear {
            guard previewState == nil else { return }
            viewModel.disconnect()
        }
        .sheet(isPresented: $showSettings) {
            VoiceConfigView(viewModel: viewModel)
        }
        .onChange(of: showSettings) { _, isPresented in
            if isPresented {
                print("⚙️ Settings opened, pausing connection...")
                viewModel.disconnect()
            } else {
                print("⚙️ Settings closed, resuming connection...")
                viewModel.connect()
            }
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            // After the user dismisses the paywall — whether they upgraded
            // or not — close the voice view. They can re-tap voice to retry.
            if let onDismiss = onDismiss { onDismiss() } else { dismiss() }
        }) {
            PaywallSheet(context: .voiceSessionLimit, source: "ios_voice_limit")
        }
    }
    
    private var statusText: String {
        switch displayedVoiceState {
        case .idle:
            return copy("Ulanmoqda…", "Уланмоқда…", "Подключение…", "Connecting…")
        case .listening:
            return copy("Eshitmoqdaman…", "Эшитмоқдаман…", "Слушаю…", "Listening…")
        case .transcribing:
            return copy("Tushunmoqdaman…", "Тушунмоқдаман…", "Распознаю…", "Understanding…")
        case .thinking:
            return copy("O‘ylayapman…", "Ўйлаяпман…", "Думаю…", "Thinking…")
        case .speaking:
            return copy("Javob bermoqdaman…", "Жавоб бермоқдаман…", "Отвечаю…", "Speaking…")
        }
    }

    private var displayedVoiceState: RealtimeVoiceState {
        previewState ?? viewModel.voiceState
    }

    private func copy(
        _ uz: String,
        _ cyrl: String,
        _ ru: String,
        _ en: String
    ) -> String {
        L4(uz: uz, kr: cyrl, ru: ru, en: en).t(languageCode)
    }
}
