import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/api_models.dart';

final chatViewModelProvider = StateNotifierProvider.autoDispose<ChatViewModel, ChatState>((ref) {
  return ChatViewModel(ref.watch(apiClientProvider));
});

class ChatState {
  final List<MessageDTO> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final ConversationSummary? currentConversation;
  final List<ConversationSummary> conversations;
  final bool isImageMode;
  final bool isGeneratingImage;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.currentConversation,
    this.conversations = const [],
    this.isImageMode = false,
    this.isGeneratingImage = false,
  });

  ChatState copyWith({
    List<MessageDTO>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    ConversationSummary? currentConversation,
    List<ConversationSummary>? conversations,
    bool? isImageMode,
    bool? isGeneratingImage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
      currentConversation: currentConversation ?? this.currentConversation,
      conversations: conversations ?? this.conversations,
      isImageMode: isImageMode ?? this.isImageMode,
      isGeneratingImage: isGeneratingImage ?? this.isGeneratingImage,
    );
  }
}

class ChatViewModel extends StateNotifier<ChatState> {
  final ApiClient _client;

  ChatViewModel(this._client) : super(ChatState());

  Future<void> loadConversations() async {
    try {
      final list = await _client.listConversations();
      state = state.copyWith(conversations: list);
    } catch (e) {
      print("Failed to list conversations: $e");
    }
  }

  Future<void> loadConversation(int id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final messages = await _client.getConversationMessages(id);

      ConversationSummary? summary;
      try {
        summary = state.conversations.firstWhere((c) => c.id == id);
      } catch (_) {
        summary = ConversationSummary(id: id, messageCount: messages.length, title: "Conversation $id");
      }

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        currentConversation: summary,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> sendMessage(String text, {int? conversationId, String? model, List<String>? attachments}) async {
    if (text.trim().isEmpty) return;

    final userMsg = MessageDTO(
      id: DateTime.now().millisecondsSinceEpoch,
      role: MessageRole.user,
      text: text,
      createdAt: DateTime.now(),
      imageUrls: attachments,
    );

    final assistantMsgId = DateTime.now().millisecondsSinceEpoch + 1;
    final assistantMsg = MessageDTO(
      id: assistantMsgId,
      role: MessageRole.assistant,
      text: "",
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isSending: true,
      errorMessage: null,
    );

    try {
      final stream = _client.streamChatMessage(
        text,
        conversationId: conversationId == 0 ? null : conversationId,
        model: model,
        attachments: attachments,
      );

      var fullText = "";
      int? finalConversationId;

      await for (final event in stream) {
        if (event.type == 'chunk' && event.content != null) {
          fullText += event.content!;
          final updatedMessages = state.messages.map((m) {
            if (m.id == assistantMsgId) {
              return MessageDTO(
                id: m.id,
                role: m.role,
                text: fullText,
                createdAt: m.createdAt,
              );
            }
            return m;
          }).toList();
          state = state.copyWith(messages: updatedMessages);
        } else if (event.type == 'done') {
          finalConversationId = event.conversationId;
        } else if (event.type == 'error') {
          state = state.copyWith(errorMessage: event.message);
        }
      }

      state = state.copyWith(isSending: false);
      loadConversations();
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: "Failed to send: $e",
      );
    }
  }

  Future<void> generateImage(String prompt) async {
    if (prompt.trim().isEmpty) return;

    final userMsg = MessageDTO(
      id: DateTime.now().millisecondsSinceEpoch,
      role: MessageRole.user,
      text: prompt,
      createdAt: DateTime.now(),
    );

    final assistantMsgId = DateTime.now().millisecondsSinceEpoch + 1;
    final assistantMsg = MessageDTO(
      id: assistantMsgId,
      role: MessageRole.assistant,
      text: "",
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isGeneratingImage: true,
      errorMessage: null,
    );

    try {
      final response = await _client.generateImage(prompt);
      final updatedMessages = state.messages.map((m) {
        if (m.id == assistantMsgId) {
          return MessageDTO(
            id: m.id,
            role: m.role,
            text: response.imageUrl != null ? '![Generated Image](${response.imageUrl})' : (response.error ?? 'Image generation failed'),
            createdAt: m.createdAt,
            imageUrls: response.imageUrl != null ? [response.imageUrl!] : null,
          );
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updatedMessages, isGeneratingImage: false);
    } catch (e) {
      final updatedMessages = state.messages.map((m) {
        if (m.id == assistantMsgId) {
          return MessageDTO(id: m.id, role: m.role, text: "Image generation failed: $e", createdAt: m.createdAt);
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updatedMessages, isGeneratingImage: false, errorMessage: e.toString());
    }
  }

  void toggleImageMode() {
    state = state.copyWith(isImageMode: !state.isImageMode);
  }

  Future<void> deleteConversation(int id) async {
    try {
      await _client.deleteConversation(id);
      final updated = state.conversations.where((c) => c.id != id).toList();
      state = state.copyWith(conversations: updated);
      if (state.currentConversation?.id == id) {
        state = state.copyWith(messages: [], currentConversation: null);
      }
    } catch (e) {
      print("Failed to delete conversation: $e");
    }
  }

  Future<List<MessageSearchHit>> searchMessages(String query) async {
    try {
      final response = await _client.searchMessages(query);
      return response.results;
    } catch (e) {
      print("Search failed: $e");
      return [];
    }
  }

  void startNewConversation() {
    state = state.copyWith(messages: [], currentConversation: null);
  }

  void clearMessages() {
    state = state.copyWith(messages: [], currentConversation: null);
  }
}
