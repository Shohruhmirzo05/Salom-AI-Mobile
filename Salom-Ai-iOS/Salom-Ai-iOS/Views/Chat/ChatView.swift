//
//  ChatView.swift
//  Salom-Ai-iOS
//
//  Created by Alijonov Shohruhmirzo on 16/11/25.
//

import SwiftUI
import Combine
import PhotosUI
import Photos
internal import UIKit

struct ChatMessage: Identifiable {
    let id: UUID
    let remoteId: Int?
    let text: String
    let role: MessageRole
    let createdAt: Date?
    var fileUrls: [String]? = nil
    var docFormat: DocFormat? = nil   // set when the user asked for a downloadable file
    var searchingWeb: Bool = false    // true while a live web search runs for this reply
    var citations: [Citation]? = nil  // web sources for this reply

    init(id: UUID = UUID(), remoteId: Int? = nil, text: String, role: MessageRole, createdAt: Date? = nil, fileUrls: [String]? = nil, docFormat: DocFormat? = nil, searchingWeb: Bool = false, citations: [Citation]? = nil) {
        self.id = id
        self.remoteId = remoteId
        self.text = text
        self.role = role
        self.createdAt = createdAt
        self.fileUrls = fileUrls
        self.docFormat = docFormat
        self.searchingWeb = searchingWeb
        self.citations = citations
    }
    
    var isUser: Bool {
        role == .user
    }
}

struct ImageViewerItem: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Real-time "is the user near the bottom" detection from the scroll geometry
/// (iOS 18). On iOS 17 it's a no-op and we fall back to a bottom-anchor marker.
struct ScrollBottomDetector: ViewModifier {
    @Binding var isAtBottom: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geo in
                // Within 120pt of the very bottom counts as "at bottom".
                geo.contentOffset.y + geo.containerSize.height >= geo.contentSize.height - 120
            } action: { _, atBottom in
                if atBottom != isAtBottom {
                    withAnimation(.easeInOut(duration: 0.2)) { isAtBottom = atBottom }
                }
            }
        } else {
            content
        }
    }
}

struct AIModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let tier: String
    let vision: Bool
    let limit: Int?
    let usage: Int?
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var conversations: [ConversationSummary] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var isTyping: Bool = false // For UI indicator
    @Published var isLoadingMessages: Bool = false
    @Published var isLoadingConversations: Bool = false
    @Published var selectedConversation: ConversationSummary?
    @Published var searchQuery: String = ""
    @Published var searchResults: [MessageSearchHit] = []
    @Published var errorMessage: String?
    
    @Published var availableModels: [AIModel] = []
    @Published var selectedModel: AIModel?
    
    // Voice
    @Published var isRecording: Bool = false
    @Published var isProcessingVoice: Bool = false
    @Published var audioLevel: Float = 0.0
    private let audioRecorder = AudioRecorder()
    
    // File Uploads
    @Published var attachments: [String] = []
    @Published var isUploading: Bool = false
    @Published var showAttachmentPicker: Bool = false
    @Published var showPhotoPicker: Bool = false
    @Published var showDocumentPicker: Bool = false
    @Published var selectedPhotoItem: PhotosPickerItem? = nil
    
    // Image Generation
    @Published var isImageMode: Bool = false
    @Published var isGeneratingImage: Bool = false
    // Web search: false = smart auto-detect (backend decides), true = force a web search.
    @Published var webSearchEnabled: Bool = false
    // Flipped when a web-search answer is blocked by the plan quota → view shows paywall.
    @Published var pendingSearchUpgrade: Bool = false

    // Document generation / preview
    @Published var generatingDocId: UUID?
    @Published var previewDoc: PreviewDocument?
    
    private let client = APIClient.shared
    private var searchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        observeSearch()
        
        audioRecorder.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: \.audioLevel, on: self)
            .store(in: &cancellables)
        
        audioRecorder.$recordingURL
            .receive(on: RunLoop.main)
            .sink { [weak self] url in
                if let url = url {
                    self?.transcribeAudio(url: url)
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func bootstrap() {
        Task {
            await loadModels()
            await loadConversations(selectFirst: false)
        }
    }
    
    func loadModels() async {
        do {
            let models = try await client.request(.getModels, decodeTo: [AIModel].self)
            await MainActor.run {
                self.availableModels = models
                if self.selectedModel == nil {
                    self.selectedModel = models.first(where: { $0.id.contains("mini") }) ?? models.first
                }
                print("Models from API:", models)
            }
        } catch {
            print("Failed to load models: \(error)")
        }
    }
    
    // MARK: - Voice
    func toggleRecording() {
        if isRecording {
            audioRecorder.stopRecording()
        } else {
            Task {
                if await audioRecorder.requestPermission() {
                    audioRecorder.startRecording()
                } else {
                    await MainActor.run {
                        errorMessage = "Mikrofon ruxsati berilmagan"
                    }
                }
            }
        }
    }
    
    private func transcribeAudio(url: URL) {
        Task {
            await MainActor.run { isProcessingVoice = true }
            
            do {
                let data = try Data(contentsOf: url)

                // Prioritise the user's chosen language for STT (defaults to Uzbek).
                let sttLang = UserDefaults.standard.string(forKey: AppStorageKeys.preferredLanguageCode) ?? "uz"
                let response = try await client.request(
                    .stt(audio: data, filename: "voice.m4a", language: sttLang),
                    decodeTo: STTResponse.self
                )
                
                await MainActor.run {
                    let t = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty {
                        // Append to whatever's already typed, like ChatGPT dictation.
                        self.inputText = self.inputText.isEmpty ? t : self.inputText + " " + t
                    } else {
                        self.errorMessage = "Ovoz aniqlanmadi, qayta urinib ko‘ring"
                    }
                    self.isProcessingVoice = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ovozni aniqlab bo‘lmadi, qayta urinib ko‘ring"
                    self.isProcessingVoice = false
                }
            }
        }
    }
    
    // MARK: - File Upload
    func uploadFile(data: Data, filename: String) {
        Task {
            await MainActor.run { isUploading = true }
            do {
                let response = try await client.request(
                    .uploadFile(data: data, filename: filename),
                    decodeTo: FileUploadResponse.self
                )
                await MainActor.run {
                    self.attachments.append(response.url)
                    self.isUploading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Fayl yuklashda xatolik: \(error.localizedDescription)"
                    self.isUploading = false
                }
            }
        }
    }
    
    func removeAttachment(at index: Int) {
        attachments.remove(at: index)
    }
    
    func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Generate filename
                let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let filename = "photo_\(Date().timeIntervalSince1970).\(ext)"
                uploadFile(data: data, filename: filename)
            }
        }
    }
    
    // MARK: - Chat
    func loadConversations(selectFirst: Bool = false) async {
        await MainActor.run {
            isLoadingConversations = true
        }
        
        defer {
            Task { @MainActor in
                isLoadingConversations = false
            }
        }
        
        do {
            print("🔄 Loading conversations...")
            let response = try await client.request(
                .listConversations(limit: 50, offset: 0),
                decodeTo: [ConversationSummary].self
            )
            print("✅ Loaded \(response.count) conversations")
            
            await MainActor.run {
                conversations = response
                
                if selectFirst, selectedConversation == nil, let first = conversations.first {
                    Task {
                        await loadConversation(id: first.id)
                    }
                } else if let currentId = selectedConversation?.id,
                          let existing = conversations.first(where: { $0.id == currentId }) {
                    selectedConversation = existing
                }
            }
        } catch {
            print("❌ Failed to load conversations: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func loadConversation(id: Int) async {
        await MainActor.run {
            isLoadingMessages = true
        }
        
        defer {
            Task { @MainActor in
                isLoadingMessages = false
            }
        }
        
        do {
            print("🔵 Loading messages for conversation \(id)...")
            
            let messagesResponse = try await client.request(
                .getConversationMessages(id: id, limit: 100, offset: 0),
                decodeTo: ConversationMessagesResponse.self
            )
            
            print("✅ API returned \(messagesResponse.messages.count) messages")
            for m in messagesResponse.messages {
                print("message \(m.id) role=\(m.role) text=\(m.text ?? "nil") imageUrls=\(m.imageUrls ?? []) fileUrls=\(m.fileUrls ?? [])")
            }
            
            await MainActor.run {
                self.objectWillChange.send()
                
                if let existing = conversations.first(where: { $0.id == id }) {
                    selectedConversation = existing
                } else {
                    selectedConversation = ConversationSummary(
                        id: id,
                        title: "Conversation \(id)",
                        updatedAt: nil,
                        messageCount: messagesResponse.total
                    )
                }
                
                var loaded = messagesResponse.messages.map { dto -> ChatMessage in
                    let attachments = (dto.imageUrls ?? []) + (dto.fileUrls ?? [])
                    return ChatMessage(
                        remoteId: dto.id,
                        text: dto.text ?? "",
                        role: dto.role,
                        createdAt: dto.createdAt,
                        fileUrls: attachments.isEmpty ? nil : attachments
                    )
                }
                // Re-attach document cards: an assistant answer whose preceding user
                // message asked for a file gets its docFormat back, so the PDF/Word
                // card reappears after reopening the app.
                for i in loaded.indices where !loaded[i].isUser && !loaded[i].text.isEmpty {
                    if let prevUser = loaded[..<i].last(where: { $0.isUser }),
                       let fmt = DocumentExporter.detectFormat(prevUser.text) {
                        loaded[i].docFormat = fmt
                    }
                }
                messages = loaded

                print("✅ UI updated with \(messages.count) messages")
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                print("❌ Failed to load conversation \(id): \(error)")
            }
        }
    }
    
    func selectConversation(_ conversation: ConversationSummary) {
        Task {
            await loadConversation(id: conversation.id)
        }
    }
    
    func startNewConversation() {
        selectedConversation = nil
        messages.removeAll()
        inputText = ""
    }
    
    func deleteConversation(_ conversation: ConversationSummary) {
        Task {
            do {
                _ = try await client.requestWithHeaders(.deleteConversation(id: conversation.id))
                conversations.removeAll { $0.id == conversation.id }
                if selectedConversation?.id == conversation.id {
                    startNewConversation()
                    await loadConversations(selectFirst: true)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    @MainActor
    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Allow sending an attachment with no text (image-only send).
        guard !isSending, (!trimmed.isEmpty || !attachments.isEmpty) else { return }

        // "pdf qil" / "word formatda ber" about the previous answer → just build the
        // file from that answer (attach the card + open it); don't rewrite it.
        if attachments.isEmpty,
           let fmt = DocumentExporter.pureFormatConversion(trimmed),
           let idx = messages.lastIndex(where: { !$0.isUser && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            inputText = ""
            var target = messages[idx]
            target.docFormat = fmt
            messages[idx] = target
            openDocument(target)
            return
        }

        inputText = ""
        let userMessage = ChatMessage(
            remoteId: nil,
            text: trimmed,
            role: .user,
            createdAt: Date(),
            fileUrls: attachments.isEmpty ? nil : attachments
        )
        
        objectWillChange.send()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            messages.append(userMessage)
        }

        isSending = true
        isTyping = true
        Analytics.shared.track("chat_message", ["has_image": !attachments.isEmpty, "length": trimmed.count])

        let currentAttachments = attachments
        attachments = []

        streamAssistant(text: trimmed,
                        attachments: currentAttachments.isEmpty ? nil : currentAttachments,
                        regenerate: false,
                        docFormat: DocumentExporter.detectFormat(trimmed))
    }

    /// Re-run the last AI answer in place using the preceding user message.
    func regenerate(_ assistant: ChatMessage) {
        guard !isSending else { return }
        guard let idx = messages.firstIndex(where: { $0.id == assistant.id }),
              let userMsg = messages[..<idx].last(where: { $0.isUser }) else { return }
        withAnimation { _ = messages.remove(at: idx) }
        isSending = true
        isTyping = true
        streamAssistant(text: userMsg.text,
                        attachments: userMsg.fileUrls,
                        regenerate: true,
                        docFormat: DocumentExporter.detectFormat(userMsg.text))
    }

    /// Server-render the answer into a clean PDF/Word/Excel and open it in-app.
    func openDocument(_ message: ChatMessage) {
        guard let fmt = message.docFormat, generatingDocId == nil else { return }
        generatingDocId = message.id
        Task {
            do {
                let resp = try await client.request(
                    .generateDocument(text: message.text, format: fmt.rawValue),
                    decodeTo: DocGenResponse.self)
                guard let remote = URL(string: resp.url) else { throw URLError(.badURL) }
                let (data, _) = try await URLSession.shared.data(from: remote)
                let local = FileManager.default.temporaryDirectory.appendingPathComponent(resp.filename)
                try data.write(to: local)
                await MainActor.run {
                    self.generatingDocId = nil
                    self.previewDoc = PreviewDocument(url: local, isPDF: fmt == .pdf)
                }
            } catch {
                await MainActor.run {
                    self.generatingDocId = nil
                    self.errorMessage = "Hujjatni yaratib boʻlmadi"
                }
            }
        }
    }

    /// Shared streaming pipeline for both fresh sends and regenerations.
    private func streamAssistant(text: String, attachments: [String]?, regenerate: Bool, docFormat: DocFormat?) {
        let currentConvId = selectedConversation?.id
        let selectedModelId = selectedModel?.id

        Task {
            do {
                let stream = client.chatStream(
                    .chatStream(conversationId: currentConvId, text: text, projectId: nil, model: selectedModelId, attachments: attachments, regenerate: regenerate, webSearch: self.webSearchEnabled, platform: "ios")
                )

                var fullText = ""
                var assistantMessageId: UUID?
                var searchingWeb = false
                var citations: [Citation]? = nil

                // Rebuild (or create) the assistant bubble with the latest state. The
                // ChatMessage is immutable, so streaming updates replace it in place,
                // carrying searchingWeb / citations across every rebuild.
                @MainActor func upsertAssistant() {
                    if let existingId = assistantMessageId,
                       let index = self.messages.firstIndex(where: { $0.id == existingId }) {
                        self.messages[index] = ChatMessage(
                            id: existingId,
                            remoteId: self.messages[index].remoteId,
                            text: fullText,
                            role: .assistant,
                            createdAt: self.messages[index].createdAt,
                            fileUrls: self.messages[index].fileUrls,
                            docFormat: docFormat,
                            searchingWeb: searchingWeb,
                            citations: citations
                        )
                    } else {
                        let newMessage = ChatMessage(
                            text: fullText,
                            role: .assistant,
                            createdAt: Date(),
                            docFormat: docFormat,
                            searchingWeb: searchingWeb,
                            citations: citations
                        )
                        assistantMessageId = newMessage.id
                        self.messages.append(newMessage)
                        self.isTyping = false
                    }
                }

                for try await event in stream {
                    switch event.type {
                    case "status":
                        // Live web search started — show a dedicated loader on the reply.
                        if event.stage == "searching_web" {
                            searchingWeb = true
                            await MainActor.run { upsertAssistant() }
                        }
                    case "chunk":
                        if let content = event.content {
                            fullText += content
                            searchingWeb = false  // first chunk clears the loader
                            await MainActor.run { upsertAssistant() }
                        }
                    case "citations":
                        if let cites = event.citations, !cites.isEmpty {
                            citations = cites
                            searchingWeb = false
                            await MainActor.run { upsertAssistant() }
                        }
                    case "search_limit":
                        // Web-search quota hit: the answer continues from the model's
                        // own knowledge; surface the upgrade paywall.
                        await MainActor.run { self.pendingSearchUpgrade = true }
                    case "done":
                        if let newId = event.conversationId {
                            await MainActor.run {
                                if self.selectedConversation == nil || self.selectedConversation?.id != newId {
                                    self.selectedConversation = ConversationSummary(
                                        id: newId,
                                        title: "Yangi suhbat",
                                        updatedAt: Date(),
                                        messageCount: self.messages.count
                                    )
                                }
                            }
                        }
                    case "error":
                        if let errorMsg = event.message {
                            await MainActor.run { self.errorMessage = errorMsg }
                        }
                    default:
                        break
                    }
                }

                await MainActor.run {
                    self.isTyping = false
                    self.isSending = false
                }

                await loadConversations(selectFirst: false)

            } catch {
                await MainActor.run {
                    self.isTyping = false
                    self.isSending = false
                    self.errorMessage = error.localizedDescription
                    print("❌ Chat error: \(error)")
                }
            }

            await MainActor.run {
                ReviewManager.shared.incrementActionCount()
            }
        }
    }
    
    @MainActor
    func generateImage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGeneratingImage else { return }
        
        inputText = ""
        let userMessage = ChatMessage(
            remoteId: nil,
            text: trimmed,
            role: .user,
            createdAt: Date()
        )
        
        objectWillChange.send()
        messages.append(userMessage)
        isGeneratingImage = true
        isTyping = true
        
        Task {
            do {
                let response = try await client.request(
                    .generateImage(conversationId: selectedConversation?.id, prompt: trimmed, projectId: nil),
                    decodeTo: ChatReplyResponse.self
                )
                
                await MainActor.run {
                    self.objectWillChange.send()
                    self.isTyping = false
                    
                    let assistantMessage = ChatMessage(
                        remoteId: nil,
                        text: "", // Empty text for image-only message
                        role: .assistant,
                        createdAt: Date(),
                        fileUrls: [response.reply] // Image URL
                    )
                    self.messages.append(assistantMessage)
                    
                    let isNewConversation = self.selectedConversation?.id != response.conversationId
                    
                    if isNewConversation {
                        self.selectedConversation = ConversationSummary(
                            id: response.conversationId,
                            title: "Image Generation",
                            updatedAt: Date(),
                            messageCount: self.messages.count
                        )
                    }
                }
                
                await loadConversations(selectFirst: false)
                
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    self.errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                self.isGeneratingImage = false
            }
        }
    }
    
    func search() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults.removeAll()
            return
        }
        
        Task {
            do {
                let response = try await client.request(
                    .searchMessages(query: trimmed, conversationId: nil),
                    decodeTo: SearchResponse.self
                )
                await MainActor.run {
                    searchResults = response.results
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func openSearchResult(_ hit: MessageSearchHit) {
        guard let conversationId = hit.conversationId else { return }
        searchQuery = ""
        searchResults.removeAll()
        Task {
            await loadConversation(id: conversationId)
            await loadConversations(selectFirst: false)
        }
    }
    
    func observeSearch() {
        searchCancellable = $searchQuery
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.search()
            }
    }
}

// MARK: - View
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    @Binding var isMenuOpen: Bool
    @State private var showUsageInfo = false
    @State private var selectedImage: ImageViewerItem?
    @State private var showPaywall = false
    @State private var isAtBottom = true
    @StateObject private var rewardAds = RewardedAdManager.shared
    @StateObject private var subs = SubscriptionManager.shared
    @State private var showRewardSheet = false
    @State private var rewardConfirmation = false
    @State private var pendingWatchAd = false
    @State private var pendingUpgrade = false

    var body: some View {
        ZStack {
            SalomTheme.Gradients.background
                .overlay(
                    RadialGradient(
                        colors: [
                            Color(hex: "#1B1E39").opacity(0.45),
                            Color.clear
                        ],
                        center: .topTrailing,
                        startRadius: 60,
                        endRadius: 520
                    )
                )
                .overlay(
                    RadialGradient(
                        colors: [
                            SalomTheme.Colors.accentPrimary.opacity(0.24),
                            .clear
                        ],
                        center: .bottomLeading,
                        startRadius: 40,
                        endRadius: 420
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                TopBar()
                SeparatorLine()
                MessagesList()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                // Subtle floating upgrade hint — only renders for free users
                // who've burned through ≥70% of any resource. No-op otherwise.
                UpgradeNudge()
                // Premium banner — free users only, hidden for Pro / when off.
                BannerAdSlot()
                InputBar()
            }
        }
        .onAppear {
            viewModel.bootstrap()
        }
        .alert("Xatolik", isPresented: Binding(
            get: { viewModel.errorMessage != nil && !isLimitExceeded(viewModel.errorMessage) },
            set: { if !$0 { viewModel.errorMessage = nil } }
        ), presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: { error in
            Text(userFriendlyError(error))
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if isLimitExceeded(newValue) {
                viewModel.errorMessage = nil
                // Always present the single reward/upgrade sheet. Don't branch
                // to a different sheet (that races SwiftUI's presentation and
                // silently fails after a few cycles). Don't stack either.
                guard !showRewardSheet && !showPaywall else { return }
                showRewardSheet = true
            }
        }
        .onChange(of: viewModel.pendingSearchUpgrade) { _, hit in
            // Web-search quota hit → go straight to the upgrade paywall.
            if hit {
                viewModel.pendingSearchUpgrade = false
                guard !showRewardSheet && !showPaywall else { return }
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
        .sheet(isPresented: $showRewardSheet, onDismiss: {
            // Runs only AFTER the sheet is fully gone from the window — safe to
            // present the full-screen ad (or the paywall) now without colliding.
            if pendingWatchAd {
                pendingWatchAd = false
                rewardAds.present { rewarded in
                    if rewarded { rewardConfirmation = true }
                }
            } else if pendingUpgrade {
                pendingUpgrade = false
                showPaywall = true
            }
        }) {
            RewardOptionSheet(
                adReady: rewardAds.isReady,
                onWatch: {
                    pendingWatchAd = true
                    showRewardSheet = false   // ad is presented in onDismiss
                },
                onUpgrade: {
                    pendingUpgrade = true
                    showRewardSheet = false   // paywall is presented in onDismiss
                }
            )
            .presentationDetents([.height(340)])
        }
        .alert("+1 xabar qo'shildi", isPresented: $rewardConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Reklama uchun rahmat! Endi xabaringizni qayta yuborishingiz mumkin.")
        }
        .sheet(isPresented: $showUsageInfo) {
            NavigationStack {
                SubscriptionView()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showUsageInfo = false } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
            }
        }
        .confirmationDialog("Fayl yuklash", isPresented: $viewModel.showAttachmentPicker) {
            Button("Rasm galereyasi") {
                viewModel.showPhotoPicker = true
            }
            Button("Hujjatlar") {
                viewModel.showDocumentPicker = true
            }
            Button("Bekor qilish", role: .cancel) { }
        }
        .photosPicker(isPresented: $viewModel.showPhotoPicker, selection: $viewModel.selectedPhotoItem, matching: .images)
        .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
            viewModel.handlePhotoSelection(newItem)
        }
        .sheet(isPresented: $viewModel.showDocumentPicker) {
            if #available(iOS 16.0, *) {
                DocumentPicker(viewModel: viewModel)
            } else {
                Text("Document picker requires iOS 16+")
            }
        }
        .fullScreenCover(item: $selectedImage) { item in
            ImageViewer(url: item.url) {
                selectedImage = nil
            }
        }
        .sheet(item: $viewModel.previewDoc) { doc in
            DocumentPreviewView(doc: doc)
        }
    }
    
    private func isLimitExceeded(_ error: String?) -> Bool {
        guard let error else { return false }
        return error.contains("LIMIT_EXCEEDED") || error.contains("limitga yetdingiz")
    }

    private func userFriendlyError(_ error: String) -> String {
        if error.contains("LIMIT_EXCEEDED") || error.contains("limitga yetdingiz") || error.contains("Quota exceeded") {
            return "Sizning obuna limitingiz tugagan. Iltimos, obunangizni yangilang."
        } else if error.contains("Invalid token") || error.contains("unauthorized") {
            return "Sessiya muddati tugagan. Qaytadan kiring."
        } else if error.contains("network") || error.contains("connection") {
            return "Internet aloqasi bilan muammo. Qayta urinib ko'ring."
        } else {
            return error
        }
    }
    
    // MARK: - Top bar (ChatGPT-style)
    @ViewBuilder func TopBar() -> some View {
        HStack(spacing: 12) {
            Button {
                HapticManager.shared.fire(.selection)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    isMenuOpen = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .salomGlassCircle(40)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedConversation?.title ?? "Salom AI")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(SalomTheme.Colors.accentPrimary)
                        .font(.caption)
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .lineLimit(1)
            }
            
            Spacer()
            
            Menu {
                ForEach(viewModel.availableModels) { model in
                    Button {
                        viewModel.selectedModel = model
                    } label: {
                        HStack {
                            Text(model.name)
                            if viewModel.selectedModel?.id == model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.selectedModel?.name ?? "Tezkor")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .salomGlassPill()
                .lineLimit(1)
            }
            
            Button {
                HapticManager.shared.fire(.selection)
                showUsageInfo = true
            } label: {
                Image(systemName: subs.isPro ? "crown.fill" : "crown")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(subs.isPro ? .yellow : .white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var statusSubtitle: LocalizedStringKey {
        if viewModel.isLoadingMessages {
            return "Yuklanmoqda..."
        }
        let count = viewModel.messages.count
        if count > 0 { return LocalizedStringKey("\(count) xabar") }
        return "O'zbekcha suniy intellekt"
    }
    
    @ViewBuilder func SeparatorLine() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
            .padding(.bottom, 4)
    }
    
    // MARK: - Messages
    @ViewBuilder func MessagesList() -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                if viewModel.messages.isEmpty && !viewModel.isLoadingMessages {
                    VStack {
                        Spacer()
                        AssistantHero()
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isGeneratingImage {
                            ImageGenerationLoadingBubble()
                                .id("image_loading_indicator")
                        } else if viewModel.isTyping {
                            TypingBubble()
                                .id("typing_indicator")
                        }

                        // iOS 17 fallback only: a 1px marker whose visibility tells us
                        // we're at the bottom. On iOS 18 ScrollBottomDetector (real
                        // scroll geometry) is used instead, so this stays inert.
                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                            .onAppear { if #unavailable(iOS 18.0) { withAnimation(.easeInOut(duration: 0.2)) { isAtBottom = true } } }
                            .onDisappear { if #unavailable(iOS 18.0) { withAnimation(.easeInOut(duration: 0.2)) { isAtBottom = false } } }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                // Start pinned to the bottom + stay pinned when the keyboard appears.
                .defaultScrollAnchor(.bottom)
                .id(viewModel.selectedConversation?.id)
                .scrollDismissesKeyboard(.interactively)
                // Real-time bottom detection (iOS 18) — drives the button + follow guard.
                .modifier(ScrollBottomDetector(isAtBottom: $isAtBottom))

                if viewModel.isLoadingMessages {
                    ProgressView().tint(.white)
                }

                // ChatGPT-style scroll-to-bottom button (glass), shown when scrolled up.
                if !isAtBottom && !viewModel.messages.isEmpty {
                    Button {
                        HapticManager.shared.fire(.lightImpact)
                        scrollToLatest(proxy: proxy, animated: true)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            // New message → animate down. Streaming tokens → follow only if already at
            // the bottom (no yank while reading). Scroll to the LAST REAL VIEW's id so
            // it reaches the true bottom (a 1px anchor only scrolled partway).
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToLatest(proxy: proxy, animated: true)
            }
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                if isAtBottom { scrollToLatest(proxy: proxy, animated: false) }
            }
            .onChange(of: viewModel.isTyping) { _, isTyping in
                if isTyping { scrollToLatest(proxy: proxy, animated: true) }
            }
            .onChange(of: viewModel.isGeneratingImage) { _, generating in
                if generating { scrollToLatest(proxy: proxy, animated: true) }
            }
        }
    }

    /// Scroll to the newest content. Targets a REAL sized view (the typing bubble,
    /// or the last message) — never a zero-height anchor — so it lands on the true
    /// bottom without the partial-scroll / phantom-space glitches.
    private func scrollToLatest(proxy: ScrollViewProxy, animated: Bool) {
        let target: AnyHashable?
        if viewModel.isGeneratingImage {
            target = "image_loading_indicator"
        } else if viewModel.isTyping {
            target = "typing_indicator"
        } else if let last = viewModel.messages.last {
            target = last.id
        } else {
            target = nil
        }
        guard let target else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(target, anchor: .bottom) }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
    
    @ViewBuilder func MessageBubble(message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
        HStack {
            if message.isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if !message.isUser && message.searchingWeb {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SalomTheme.Colors.accentPrimary)
                        Text("Internetdan qidirilmoqda…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(SalomTheme.Colors.accentPrimary)
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(SalomTheme.Colors.accentPrimary)
                    }
                }

                if let fileUrls = message.fileUrls, !fileUrls.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(fileUrls, id: \.self) { url in
                            if isImageURL(url) {
                                AttachmentImage(url: url) {
                                    if let link = URL(string: url) {
                                        selectedImage = ImageViewerItem(url: link)
                                    }
                                }
                            } else {
                                AttachmentFile(url: url)
                            }
                        }
                    }
                }
                
                if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Group {
                        if message.isUser {
                            Text(message.text)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                        } else {
                            MarkdownText(text: message.text)   // rich formatting, like web
                        }
                    }
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Web sources / citations
                if !message.isUser, let citations = message.citations, !citations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                            ForEach(Array(citations.enumerated()), id: \.offset) { idx, cite in
                                if let url = URL(string: cite.url) {
                                    Link(destination: url) {
                                        Text("\(idx + 1). \(sourceHost(cite.url))")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(SalomTheme.Colors.accentPrimary)
                                            .lineLimit(1)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.white.opacity(0.06))
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        message.isUser
                        ? LinearGradient(
                            colors: [
                                SalomTheme.Colors.accentPrimary,
                                SalomTheme.Colors.accentSecondary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(message.isUser ? 0.14 : 0.06))
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 10)
            )
            .frame(
                maxWidth: UIScreen.main.bounds.width * 0.78,
                alignment: message.isUser ? .trailing : .leading
            )
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
        
        .padding(.horizontal, 4)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Nusxalash", systemImage: "doc.on.doc")
            }
            
            if let fileUrls = message.fileUrls, let firstUrl = fileUrls.first, let url = URL(string: firstUrl) {
                ShareLink(item: url) {
                    Label("Ulashish", systemImage: "square.and.arrow.up")
                }
            } else if !message.text.isEmpty {
                ShareLink(item: message.text) {
                    Label("Ulashish", systemImage: "square.and.arrow.up")
                }
            }
        }

            // AI answer extras: a document card (only if the user asked for a file)
            // + the action row (copy / share / regenerate / 👍 / 👎). Hidden while
            // this message is still streaming.
            if !message.isUser,
               !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !(viewModel.isSending && message.id == viewModel.messages.last?.id) {

                if let fmt = message.docFormat {
                    Button {
                        HapticManager.shared.fire(.mediumImpact)
                        viewModel.openDocument(message)
                    } label: {
                        HStack(spacing: 10) {
                            if viewModel.generatingDocId == message.id {
                                ProgressView().tint(SalomTheme.Colors.accentPrimary).frame(width: 22, height: 22)
                            } else {
                                Image(systemName: fmt.icon).foregroundColor(SalomTheme.Colors.accentPrimary)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(fmt.label).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                                Text(viewModel.generatingDocId == message.id ? "Tayyorlanmoqda…" : "Ochish")
                                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.5))
                            }
                            Spacer(minLength: 0)
                            if viewModel.generatingDocId != message.id {
                                Image(systemName: "eye").foregroundColor(SalomTheme.Colors.accentPrimary)
                            }
                        }
                        .padding(12)
                        .background(SalomTheme.Colors.accentPrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SalomTheme.Colors.accentPrimary.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.generatingDocId != nil)
                    .padding(.leading, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                MessageActions(message: message, model: viewModel.selectedModel?.id) {
                    viewModel.regenerate(message)
                }
                .padding(.leading, 8)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder func TypingBubble() -> some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(0), value: viewModel.isTyping)
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2), value: viewModel.isTyping)
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.4), value: viewModel.isTyping)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .transition(.opacity)
    }
    
    @ViewBuilder func ImageGenerationLoadingBubble() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .shimmering()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 16)
                    .shimmering()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .transition(.opacity)
    }
    
    @ViewBuilder func AssistantHero() -> some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                SalomTheme.Colors.accentSecondary.opacity(0.9),
                                SalomTheme.Colors.accentPrimary.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .blur(radius: 16)
                    .opacity(0.7)
                
                Image("main-character")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1.2))
                    .shadow(color: SalomTheme.Colors.accentPrimary.opacity(0.4), radius: 26, x: 0, y: 16)
            }
            Spacer()
        }
    }
    
    // MARK: - Input bar
    @ViewBuilder func InputBar() -> some View {
        VStack(spacing: 12) {
            if viewModel.isRecording {
                VStack(spacing: 6) {
                    VoiceVisualizer(level: viewModel.audioLevel)
                        .frame(height: 36)
                        .padding(.horizontal, 20)
                    HStack(spacing: 6) {
                        Circle().fill(Color.red).frame(width: 7, height: 7)
                        Text("Ovoz yozilmoqda…")
                            .font(.caption).foregroundColor(SalomTheme.Colors.textSecondary)
                    }
                }
                .padding(.bottom, 2)
            } else if viewModel.isProcessingVoice {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8).tint(SalomTheme.Colors.accentPrimary)
                    Text("Matnga aylantirilmoqda…")
                        .font(.caption).foregroundColor(SalomTheme.Colors.textSecondary)
                }
                .padding(.bottom, 4)
            }
            
            if !viewModel.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.attachments.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: URL(string: viewModel.attachments[index])) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                
                                Button {
                                    viewModel.removeAttachment(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    IconBubble(
                        systemName: viewModel.isImageMode ? "photo.fill" : "photo",
                        isActive: viewModel.isImageMode,
                        action: {
                            HapticManager.shared.fire(.mediumImpact)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.isImageMode.toggle()
                            }
                        }
                    )
                    .disabled(viewModel.isRecording || viewModel.isProcessingVoice || viewModel.isGeneratingImage)

                    // Web search: off = smart auto-detect, on = force a web search.
                    IconBubble(
                        systemName: "globe",
                        isActive: viewModel.webSearchEnabled,
                        action: {
                            HapticManager.shared.fire(.mediumImpact)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.webSearchEnabled.toggle()
                            }
                        }
                    )
                    .disabled(viewModel.isImageMode || viewModel.isRecording || viewModel.isProcessingVoice || viewModel.isGeneratingImage)

                    Menu {
                        Button {
                            viewModel.showPhotoPicker = true
                        } label: {
                            Label("Rasm galereyasi", systemImage: "photo")
                        }
                        
                        Button {
                            viewModel.showDocumentPicker = true
                        } label: {
                            Label("Hujjatlar", systemImage: "doc")
                        }
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(viewModel.isUploading ? .white : SalomTheme.Colors.accentPrimary)
                            .frame(width: 40, height: 40)
                            .background(
                                Group {
                                    if viewModel.isUploading {
                                        LinearGradient(
                                            colors: [SalomTheme.Colors.accentPrimary, SalomTheme.Colors.accentSecondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    } else {
                                        Color.white.opacity(0.08)
                                    }
                                }
                            )
                            .clipShape(Circle())
                            .overlay(
                                Group {
                                    if viewModel.isUploading {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                            )
                    }
                    .disabled(viewModel.isRecording || viewModel.isProcessingVoice || viewModel.isUploading || viewModel.isImageMode)

                    Spacer()
                }
                
                HStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: viewModel.isImageMode ?
                                    [Color(hex: "#A855F7").opacity(0.18), Color(hex: "#EC4899").opacity(0.18)] :
                                        [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.08))
                            )
                        
                        TextField(
                            viewModel.isImageMode ? "Rasm tavsifini kiriting..." : "Savol bering yoki gapiring...",
                            text: $viewModel.inputText,
                            axis: .vertical
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                        .lineLimit(1...4)
                        .disabled(viewModel.isRecording || viewModel.isProcessingVoice)
                    }
                    .frame(maxHeight: 76)

                    // Voice → text (dictation). Tap to record, tap to stop; the
                    // transcription (OpenAI STT via /voice/stt) fills the field.
                    Button {
                        HapticManager.shared.fire(.mediumImpact)
                        viewModel.toggleRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(viewModel.isRecording ? Color.red : Color.white.opacity(0.08))
                                .frame(width: 44, height: 44)
                            if viewModel.isProcessingVoice {
                                ProgressView().tint(SalomTheme.Colors.accentPrimary)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(viewModel.isRecording ? .white : SalomTheme.Colors.accentPrimary)
                            }
                        }
                    }
                    .disabled(viewModel.isImageMode || viewModel.isProcessingVoice)

                    Button {
                        HapticManager.shared.fire(.lightImpact)
                        if viewModel.isImageMode {
                            viewModel.generateImage()
                        } else {
                            viewModel.sendMessage()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [SalomTheme.Colors.accentPrimary, SalomTheme.Colors.accentSecondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                                .shadow(color: SalomTheme.Colors.accentPrimary.opacity(0.4), radius: 10, x: 0, y: 6)
                            
                            if viewModel.isSending || viewModel.isGeneratingImage {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: viewModel.isImageMode ? "wand.and.stars" : "paperplane.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(
                        viewModel.isRecording || viewModel.isProcessingVoice ||
                        // Image-gen needs a prompt; normal send allows image-only.
                        (viewModel.isImageMode
                            ? viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            : (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.attachments.isEmpty))
                    )
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    struct IconBubble: View {
        let systemName: String
        var isActive: Bool = false
        var activeTint: Color = SalomTheme.Colors.accentPrimary
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                if isActive {
                    Image(systemName: systemName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            LinearGradient(
                                colors: [SalomTheme.Colors.accentPrimary, SalomTheme.Colors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(activeTint)
                        .salomGlassCircle(40)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    struct VoiceVisualizer: View {
        let level: Float
        
        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<20) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SalomTheme.Colors.accentPrimary)
                        .frame(width: 3, height: height(for: index))
                        .animation(.easeInOut(duration: 0.1), value: level)
                }
            }
        }
        
        func height(for index: Int) -> CGFloat {
            let baseHeight: CGFloat = 10
            let maxAdditionalHeight: CGFloat = 30
            
            let center = 9.5
            let dist = abs(Double(index) - center)
            let scale = max(0.0, 1.0 - (dist / 10.0))
            
            let random = CGFloat.random(in: 0.8...1.2)
            
            let dynamicHeight = CGFloat(level) * maxAdditionalHeight * CGFloat(scale) * random
            
            return baseHeight + dynamicHeight
        }
    }
    
    // MARK: - Attachment helpers
    private func isImageURL(_ url: String) -> Bool {
        let cleanUrl = url.components(separatedBy: "?").first ?? url
        let lower = cleanUrl.lowercased()
        return lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png") || lower.hasSuffix(".webp") || lower.hasSuffix(".gif") || lower.hasSuffix(".heic")
    }

    /// Short, readable label for a citation link (host without the "www.").
    private func sourceHost(_ url: String) -> String {
        guard let host = URL(string: url)?.host else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    
    struct AttachmentImage: View {
        let url: String
        var onTap: (() -> Void)? = nil
        @State private var saving = false
        @State private var saved = false

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                // Tap the image → open full-screen viewer.
                Button { onTap?() } label: {
                    CachedImage(imageUrl: url, contentMode: .fill)
                        .frame(width: 260, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                // Clean one-tap save to Photos (no share sheet). Checkmark on success.
                Button {
                    saveToPhotos()
                } label: {
                    Group {
                        if saving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: saved ? "checkmark" : "arrow.down")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(10)
                }
                .buttonStyle(.plain)
                .disabled(saving)
            }
        }

        private func saveToPhotos() {
            guard let u = URL(string: url), !saving else { return }
            saving = true
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: u)
                    guard let img = UIImage(data: data) else { await MainActor.run { saving = false }; return }
                    ImageSaver.shared.save(img)
                    await MainActor.run { saving = false; saved = true; HapticManager.shared.fire(.mediumImpact) }
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    await MainActor.run { saved = false }
                } catch {
                    await MainActor.run { saving = false }
                }
            }
        }
    }

    final class ImageSaver: NSObject {
        static let shared = ImageSaver()
        func save(_ image: UIImage) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
    
    struct AttachmentFile: View {
        let url: String
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundColor(.white.opacity(0.8))
                Text(URL(string: url)?.lastPathComponent ?? "File")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer()
                if let link = URL(string: url) {
                    ShareLink(item: link) {
                        Image(systemName: "arrow.down.to.line.compact")
                            .foregroundColor(SalomTheme.Colors.accentPrimary)
                    }
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    struct MessageActions: View {
        let message: ChatMessage
        let model: String?
        var onRegenerate: () -> Void = {}
        @State private var rating: String? = nil
        @State private var copied = false

        var body: some View {
            HStack(spacing: 2) {
                iconButton(copied ? "checkmark" : "doc.on.doc", tint: copied ? .green : .white.opacity(0.45)) {
                    UIPasteboard.general.string = message.text
                    HapticManager.shared.fire(.lightImpact)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation { copied = false } }
                }

                ShareLink(item: message.text) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.45))
                        .frame(width: 32, height: 28)
                }

                iconButton("arrow.clockwise", tint: .white.opacity(0.45)) {
                    HapticManager.shared.fire(.lightImpact)
                    onRegenerate()
                }

                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 15).padding(.horizontal, 3)

                iconButton(rating == "up" ? "hand.thumbsup.fill" : "hand.thumbsup",
                           tint: rating == "up" ? SalomTheme.Colors.accentPrimary : .white.opacity(0.45)) { setRating("up") }
                iconButton(rating == "down" ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                           tint: rating == "down" ? .red.opacity(0.85) : .white.opacity(0.45)) { setRating("down") }
            }
        }

        @ViewBuilder
        private func iconButton(_ icon: String, tint: Color, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(tint).frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
        }

        private func setRating(_ r: String) {
            let newVal: String? = (rating == r) ? nil : r
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { rating = newVal }
            HapticManager.shared.fire(.lightImpact)
            guard let nv = newVal else { return }
            Analytics.shared.track("ai_feedback", [
                "rating": nv,
                "model": model ?? "",
                "preview": String(message.text.prefix(200))
            ])
        }
    }
}
