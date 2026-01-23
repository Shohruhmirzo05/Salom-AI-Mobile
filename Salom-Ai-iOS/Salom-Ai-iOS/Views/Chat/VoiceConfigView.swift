//
//  VoiceConfigView.swift
//  Salom-Ai-iOS
//
//  Created by Codex on 27/11/25.
//

import SwiftUI

struct VoiceConfigView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: RealtimeVoiceViewModel
    
    @State private var selectedLanguage: String = "uz-UZ"
    @State private var selectedVoice: String = "nigora"
    @State private var selectedRole: String = "neutral"
    
    // Configuration Data
    let languages = [
        ("uz-UZ", "🇺🇿 O'zbekcha"),
        ("ru-RU", "🇷🇺 Русский"),
        ("en-US", "🇺🇸 English")
    ]
    
    let voices: [String: [(id: String, name: String, roles: [String])]] = [
        "uz-UZ": [
            ("nigora", "Nigora (Ayol)", ["neutral"]),
            ("zamira", "Zamira (Ayol)", ["neutral", "strict", "friendly"]),
            ("yulduz", "Yulduz (Ayol)", ["neutral", "strict", "friendly", "whisper"])
        ],
        "ru-RU": [
            ("alena", "Alena (Ayol)", ["neutral", "good"]),
            ("filipp", "Filipp (Erkak)", ["neutral"]),
            ("ermil", "Ermil (Erkak)", ["neutral", "good"]),
            ("jane", "Jane (Ayol)", ["neutral"]),
            ("madirus", "Madirus (Erkak)", ["neutral"]),
            ("omazh", "Omazh (Ayol)", ["neutral"]),
            ("zahar", "Zahar (Erkak)", ["neutral"])
        ],
        "en-US": [
            ("john", "John (Erkak)", ["neutral"]),
            ("lea", "Lea (Ayol)", ["neutral"]),
            ("naomi", "Naomi (Ayol)", ["neutral"]) // Assuming standard voices
        ]
    ]
    
    var currentVoices: [(id: String, name: String, roles: [String])] {
        voices[selectedLanguage] ?? []
    }
    
    var currentRoles: [String] {
        currentVoices.first(where: { $0.id == selectedVoice })?.roles ?? ["neutral"]
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Til (Language)")) {
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(languages, id: \.0) { lang in
                            Text(lang.1).tag(lang.0)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedLanguage) { _, newValue in
                        // Reset voice to first available when language changes
                        if let firstVoice = voices[newValue]?.first {
                            selectedVoice = firstVoice.id
                            selectedRole = firstVoice.roles.first ?? "neutral"
                        }
                        updateConfig()
                    }
                }
                
                Section(header: Text("Ovoz (Voice)")) {
                    Picker("Voice", selection: $selectedVoice) {
                        ForEach(currentVoices, id: \.id) { voice in
                            Text(voice.name).tag(voice.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedVoice) { _, newValue in
                        // Reset role if current role is not supported
                        if !currentRoles.contains(selectedRole) {
                            selectedRole = currentRoles.first ?? "neutral"
                        }
                        updateConfig()
                    }
                }
                
                if currentRoles.count > 1 {
                    Section(header: Text("Ohang (Tone)")) {
                        Picker("Tone", selection: $selectedRole) {
                            ForEach(currentRoles, id: \.self) { role in
                                Text(role.capitalized).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedRole) { _, _ in
                            updateConfig()
                        }
                    }
                }
                
                Section(footer: Text("O'zgarishlar darhol qo'llaniladi va namuna eshittiriladi.")) {
                    Button(action: {
                        updateConfig()
                    }) {
                        HStack {
                            if isPreviewLoading {
                                ProgressView()
                                    .padding(.trailing, 5)
                            } else {
                                Image(systemName: "play.circle.fill")
                            }
                            Text(isPreviewLoading ? "Yuklanmoqda..." : "Namuna eshitish (Preview)")
                        }
                    }
                    .disabled(isPreviewLoading)
                }
            }
            .navigationTitle("Sozlamalar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Yopish") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSavedSettings()
        }
    }
    
    @State private var isPreviewLoading = false
    
    private func updateConfig() {
        // Debounce update to prevent multiple calls
        NSObject.cancelPreviousPerformRequests(withTarget: viewModel.wsManager)
        
        // Save to UserDefaults
        UserDefaults.standard.set(selectedLanguage, forKey: "voice_language")
        UserDefaults.standard.set(selectedVoice, forKey: "voice_id")
        UserDefaults.standard.set(selectedRole, forKey: "voice_role")
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            
            await MainActor.run {
                print("⚙️ Updating config: \(selectedLanguage) / \(selectedVoice) / \(selectedRole)")
                viewModel.stopAudio() // Stop current playback
                
                // Update local state immediately
                viewModel.wsManager.currentLanguage = selectedLanguage
                
                // Trigger preview (which also saves settings)
                isPreviewLoading = true
                Task {
                    do {
                        try await viewModel.previewVoice(
                            language: selectedLanguage,
                            voice: selectedVoice,
                            role: selectedRole
                        )
                    } catch {
                        print("❌ Preview failed: \(error.localizedDescription)")
                    }
                    await MainActor.run {
                        isPreviewLoading = false
                    }
                }
            }
        }
    }
    
    private func loadSavedSettings() {
        if let savedLang = UserDefaults.standard.string(forKey: "voice_language") {
            selectedLanguage = savedLang
        }
        if let savedVoice = UserDefaults.standard.string(forKey: "voice_id") {
            selectedVoice = savedVoice
        }
        if let savedRole = UserDefaults.standard.string(forKey: "voice_role") {
            selectedRole = savedRole
        }
        
        // Update WebSocket manager's current language so header displays correctly
        viewModel.wsManager.currentLanguage = selectedLanguage
        
        print("📥 Loaded saved settings: \(selectedLanguage)/\(selectedVoice)/\(selectedRole)")
    }
}
