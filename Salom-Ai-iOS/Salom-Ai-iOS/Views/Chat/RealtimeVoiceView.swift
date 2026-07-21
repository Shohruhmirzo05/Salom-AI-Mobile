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
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showBlockAlert = false
    @State private var didRunPreflight = false
    var onDismiss: (() -> Void)?
    
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
                    audioLevel: viewModel.audioLevel,
                    state: viewModel.voiceState
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

                        Text("Sinov rejimi — xatolar bo'lishi mumkin")
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
                            
                            Text(viewModel.isMuted ? "Ovoz yoqish" : "Ovoz o'chirish")
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
                            
                            Text("Tugatish")
                                .font(.caption)
                                .foregroundColor(SalomTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
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
        switch viewModel.voiceState {
        case .idle: return NSLocalizedString("Ulanmoqda...", comment: "Connecting")
        case .listening: return NSLocalizedString("Eshitmoqdaman...", comment: "Listening")
        case .transcribing: return NSLocalizedString("Tushunmoqdaman...", comment: "Transcribing")
        case .thinking: return NSLocalizedString("O'ylayapman...", comment: "Thinking")
        case .speaking: return NSLocalizedString("Gapiryapman...", comment: "Speaking")
        }
    }
}
