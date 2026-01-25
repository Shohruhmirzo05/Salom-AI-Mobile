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
  
  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.currentConversation,
    this.conversations = const [],
  });
  
  ChatState copyWith({
    List<MessageDTO>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    ConversationSummary? currentConversation,
    List<ConversationSummary>? conversations,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
      currentConversation: currentConversation ?? this.currentConversation,
      conversations: conversations ?? this.conversations,
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
      
      // Update or find conversation summary
      ConversationSummary? summary;
      try {
        summary = state.conversations.firstWhere((c) => c.id == id);
      } catch (_) {
         // Create temporary if not found
         summary = ConversationSummary(id: id, messageCount: messages.length, title: "Conversation $id");
      }

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        currentConversation: summary
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
  
  Future<void> sendMessage(String text, {int? conversationId, String? model}) async {
    if (text.trim().isEmpty) return;
    
    final tempMsg = MessageDTO(
      id: 0,
      role: MessageRole.user,
      text: text,
      createdAt: DateTime.now(),
    );
    
    state = state.copyWith(
      messages: [...state.messages, tempMsg],
      isSending: true,
      errorMessage: null,
    );
    
    try {
      final response = await _client.sendChatMessage(
        text,
        conversationId: conversationId == 0 ? null : conversationId,
        model: model
      );
      
      final replyMsg = MessageDTO(
        id: 1, 
        role: MessageRole.assistant,
        text: response.reply,
        createdAt: DateTime.now(),
      );
      
      // If new conversation started
      if (conversationId == null || conversationId == 0) {
         // Optionally reload conversation to get full state including real IDs
         // But for now just append
         // Ideally we should switch context to the new ID
      }
      
      state = state.copyWith(
        messages: [...state.messages, replyMsg],
        isSending: false
      );
      
      // Refresh conversations in background
      loadConversations();
      
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: "Failed to send: $e",
        // remove temp message? Or show error state on it.
      );
    }
  }
  
  void clearMessages() {
    state = state.copyWith(messages: [], currentConversation: null);
  }
}
