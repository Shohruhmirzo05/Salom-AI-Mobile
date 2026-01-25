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

struct ChatMessage: Identifiable {
    let id: UUID
    let remoteId: Int?
    let text: String
    let role: MessageRole
    let createdAt: Date?
    var fileUrls: [String]? = nil
    
    init(id: UUID = UUID(), remoteId: Int? = nil, text: String, role: MessageRole, createdAt: Date? = nil, fileUrls: [String]? = nil) {
        self.id = id
        self.remoteId = remoteId
        self.text = text
        self.role = role
        self.createdAt = createdAt
        self.fileUrls = fileUrls
    }
    
    var isUser: Bool {
        role == .user
    }
}

struct ImageViewerItem: Identifiable {
    let url: URL
    var id: URL { url }
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
                
                let response = try await client.request(
                    .stt(audio: data, filename: "voice.m4a"),
                    decodeTo: STTResponse.self
                )
                
                await MainActor.run {
                    self.inputText = response.text
                    self.isProcessingVoice = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Ovozni matnga aylantirishda xatolik: \(error.localizedDescription)"
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
                
                messages = messagesResponse.messages.map { dto in
                    let attachments = (dto.imageUrls ?? []) + (dto.fileUrls ?? [])
                    return ChatMessage(
                        remoteId: dto.id,
                        text: dto.text ?? "",
                        role: dto.role,
                        createdAt: dto.createdAt,
                        fileUrls: attachments.isEmpty ? nil : attachments
                    )
                }
                
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
        guard !trimmed.isEmpty, !isSending else { return }
        
        inputText = ""
        let userMessage = ChatMessage(
            remoteId: nil,
            text: trimmed,
            role: .user,
            createdAt: Date(),
            fileUrls: attachments.isEmpty ? nil : attachments
        )
        
        objectWillChange.send()
        messages.append(userMessage)
        
        isSending = true
        isTyping = true
        
        let currentAttachments = attachments
        attachments = []
        
        let currentConvId = selectedConversation?.id
        let selectedModelId = selectedModel?.id
        
        Task {
            do {
                let stream = client.chatStream(
                    .chatStream(conversationId: currentConvId, text: trimmed, projectId: nil, model: selectedModelId, attachments: currentAttachments.isEmpty ? nil : currentAttachments)
                )
                
                var fullText = ""
                var assistantMessageId: UUID?
                
                for try await event in stream {
                    switch event.type {
                    case "chunk":
                        if let content = event.content {
                            fullText += content
                            await MainActor.run {
                                if let existingId = assistantMessageId,
                                   let index = self.messages.firstIndex(where: { $0.id == existingId }) {
                                    // Update existing message
                                    self.messages[index] = ChatMessage(
                                        id: existingId,
                                        remoteId: self.messages[index].remoteId,
                                        text: fullText,
                                        role: .assistant,
                                        createdAt: self.messages[index].createdAt
                                    )
                                } else {
                                    // First chunk: Create message and hide typing indicator
                                    let newMessage = ChatMessage(
                                        text: fullText,
                                        role: .assistant,
                                        createdAt: Date()
                                    )
                                    assistantMessageId = newMessage.id
                                    self.messages.append(newMessage)
                                    self.isTyping = false
                                }
                            }
                        }
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
                            await MainActor.run {
                                self.errorMessage = errorMsg
                            }
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
    @State private var showRealtimeVoice = false
    
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
                InputBar()
            }
        }
        .onAppear {
            viewModel.bootstrap()
        }
        .alert("Xatolik", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        ), presenting: viewModel.errorMessage) { _ in
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: { error in
            Text(userFriendlyError(error))
        }
        .sheet(isPresented: $showUsageInfo) {
            if #available(iOS 16.0, *) {
                UsageInfoView()
            } else {
                Text("Usage info requires iOS 16+")
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
    }
    
    private func userFriendlyError(_ error: String) -> String {
        if error.contains("Quota exceeded") {
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
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
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
                .background(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .lineLimit(1)
            }
            
            Button {
                showUsageInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
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
            ZStack {
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
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.messages.count)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.isTyping)
                }
                .id(viewModel.selectedConversation?.id)
                
                if viewModel.isLoadingMessages {
                    ProgressView()
                        .tint(.white)
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.text) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isTyping) { _, isTyping in
                if isTyping {
                    scrollToBottom(proxy: proxy, id: "typing_indicator")
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, id: AnyHashable? = nil) {
        if let id = id {
            withAnimation(.easeOut) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        } else if let lastId = viewModel.messages.last?.id {
            withAnimation(.easeOut) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
    
    @ViewBuilder func MessageBubble(message: ChatMessage) -> some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: .leading, spacing: 6) {
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
                    Text(message.text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
                VoiceVisualizer(level: viewModel.audioLevel)
                    .frame(height: 40)
                    .padding(.horizontal, 20)
            } else if viewModel.isProcessingVoice {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(SalomTheme.Colors.accentPrimary)
                    Text("Ovoz qayta ishlanmoqda...")
                        .font(.caption)
                        .foregroundColor(SalomTheme.Colors.textSecondary)
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
                    
                    Button {
                        HapticManager.shared.fire(.mediumImpact)
                        showRealtimeVoice = true
                    } label: {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(SalomTheme.Colors.accentPrimary)
                    }
                    .disabled(viewModel.isProcessingVoice || viewModel.isImageMode)
                    .fullScreenCover(isPresented: $showRealtimeVoice) {
                        RealtimeVoiceView()
                    }
                    
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
                    .disabled(viewModel.isRecording || viewModel.isProcessingVoice || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isActive ? .white : activeTint)
                    .frame(width: 40, height: 40)
                    .background(
                        Group {
                            if isActive {
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
    
    struct AttachmentImage: View {
        let url: String
        var onTap: (() -> Void)? = nil
        
        var body: some View {
            Button {
                onTap?()
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    CachedImage(imageUrl: url, contentMode: .fill)
                        .frame(maxWidth: 260, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.1))
                        )
                    
                    if let link = URL(string: url) {
                        ShareLink(item: link) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(8)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
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
}
