//
//  VoiceConfigView.swift
//  Salom-Ai-iOS
//
//  Real-time voice settings — language + voice picker with previews.
//  Language is bidirectionally synced with the chat header via the global
//  AppStorage key `preferredLanguageCode`. Voice choice is per-user and
//  persisted both locally (AppStorage) and on the backend.
//

import SwiftUI

/// Per-user voice preference key (AppStorage).
private enum RealtimeVoicePrefs {
    static let selectedVoice = "salom.realtime.openai.voice"
}

/// An OpenAI Realtime voice option.
struct OpenAIVoice: Identifiable, Hashable {
    let id: String          // API id sent to OpenAI (e.g. "marin")
    let displayName: String // Human label (e.g. "Marin")
    let description: String // 1-line vibe (e.g. "Warm, natural")
}

struct VoiceConfigView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: RealtimeVoiceViewModel

    // Source of truth — same key the chat header uses, so it propagates both ways.
    @AppStorage(AppStorageKeys.preferredLanguageCode) private var languageCode: String = "uz"

    @AppStorage(RealtimeVoicePrefs.selectedVoice) private var selectedVoice: String = "marin"

    @State private var previewingVoice: String? = nil  // voice id currently sampling
    @State private var previewError: String? = nil

    // Languages supported in the live voice mode. Short ISO codes match the
    // backend session-prompt keys ("uz", "ru", "en"). "uz-Cyrl" maps down
    // to "uz" on the wire since the backend doesn't distinguish scripts.
    private let languages: [(code: String, label: String)] = [
        ("uz",      "🇺🇿 O'zbekcha"),
        ("uz-Cyrl", "🇺🇿 Кириллча"),
        ("ru",      "🇷🇺 Русский"),
        ("en",      "🇬🇧 English"),
    ]

    // OpenAI Realtime GA voices. Order matches OpenAI's recommended quality
    // ranking for natural conversation (marin / cedar are the newest).
    private let voices: [OpenAIVoice] = [
        .init(id: "marin",  displayName: "Marin",  description: "Warm, friendly female"),
        .init(id: "cedar",  displayName: "Cedar",  description: "Warm, grounded male"),
        .init(id: "alloy",  displayName: "Alloy",  description: "Neutral, balanced"),
        .init(id: "sage",   displayName: "Sage",   description: "Calm, thoughtful"),
        .init(id: "verse",  displayName: "Verse",  description: "Energetic, expressive"),
        .init(id: "ash",    displayName: "Ash",    description: "Soft, clear"),
        .init(id: "ballad", displayName: "Ballad", description: "Smooth, melodic"),
        .init(id: "coral",  displayName: "Coral",  description: "Bright, upbeat"),
    ]

    var body: some View {
        NavigationView {
            Form {
                // MARK: Language
                Section(header: Text("Til")) {
                    Picker("", selection: $languageCode) {
                        ForEach(languages, id: \.code) { lang in
                            Text(lang.label).tag(lang.code)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: languageCode) { _, newValue in
                        applyLanguageChange(newValue)
                    }
                }

                // MARK: Voice
                Section(
                    header: Text("Ovoz"),
                    footer: Text("Suhbat boshlanganidan keyin ovoz keyingi sessiyada qo'llaniladi.")
                        .font(.caption)
                ) {
                    ForEach(voices) { voice in
                        VoiceRow(
                            voice: voice,
                            isSelected: voice.id == selectedVoice,
                            isPreviewing: previewingVoice == voice.id,
                            onSelect: {
                                selectedVoice = voice.id
                                applyVoiceChange(voice.id)
                            },
                            onPreview: { Task { await previewVoice(voice.id) } }
                        )
                    }
                }

                if let err = previewError {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Sozlamalar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Yopish") { dismiss() }
                }
            }
        }
    }

    // MARK: - Actions

    private func applyLanguageChange(_ code: String) {
        // Map "uz-Cyrl" → "uz" on the wire (backend doesn't split scripts).
        let wireCode = code.hasPrefix("uz") ? "uz" : code
        viewModel.wsManager.changeLanguage(wireCode, voice: nil, role: nil)

        // Also persist to backend profile via REST so it's consistent across
        // devices and the chat header reflects it on next launch.
        Task {
            guard let token = TokenStore.shared.accessToken else { return }
            do {
                let url = URL(string: "https://api.salom-ai.uz/auth/me")!
                var req = URLRequest(url: url)
                req.httpMethod = "PUT"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["language": code])
                _ = try await URLSession.shared.data(for: req)
            } catch {
                print("⚠️ [VoiceConfig] Failed to sync language to backend: \(error)")
            }
        }
    }

    private func applyVoiceChange(_ voiceId: String) {
        // Persist on the backend so future sessions pick it up via session.update.
        // (Mid-session voice swap is not supported by OpenAI Realtime — applies
        // on the NEXT connect.)
        Task {
            guard let token = TokenStore.shared.accessToken else { return }
            do {
                let url = URL(string: "https://api.salom-ai.uz/realtime/voice")!
                var req = URLRequest(url: url)
                req.httpMethod = "PUT"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["voice": voiceId])
                _ = try await URLSession.shared.data(for: req)
            } catch {
                print("⚠️ [VoiceConfig] Voice persist failed: \(error)")
            }
        }
    }

    private func previewVoice(_ voiceId: String) async {
        previewError = nil
        previewingVoice = voiceId
        defer { Task { @MainActor in previewingVoice = nil } }

        do {
            let wireLang = languageCode.hasPrefix("uz") ? "uz" : languageCode
            guard let token = TokenStore.shared.accessToken else {
                previewError = String.appLocalized("Kirish talab qilinadi")
                return
            }
            let url = URL(string: "https://api.salom-ai.uz/realtime/voice-preview?voice=\(voiceId)&lang=\(wireLang)")!
            var req = URLRequest(url: url)
            req.timeoutInterval = 15
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                previewError = String(
                    format: String.appLocalized("Ovoz namunasini yuklab bo‘lmadi (HTTP %lld)"),
                    (response as? HTTPURLResponse)?.statusCode ?? 0
                )
                return
            }

            // Stop any active call playback briefly so the sample is heard.
            await MainActor.run {
                viewModel.stopAudio()
                // The audio manager handles MP3 directly.
                viewModel.playPreview(data: data)
            }
        } catch {
            previewError = String.appLocalized("Ovoz namunasida xatolik: ") + error.localizedDescription
        }
    }
}

// MARK: - Row UI

private struct VoiceRow: View {
    let voice: OpenAIVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(voice.displayName)
                            .font(.body)
                        Text(String.appLocalized(voice.description))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onPreview) {
                if isPreviewing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
            .disabled(isPreviewing)
        }
        .padding(.vertical, 4)
    }
}
