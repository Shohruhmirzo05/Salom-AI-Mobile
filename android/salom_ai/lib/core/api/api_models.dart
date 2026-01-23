import 'package:json_annotation/json_annotation.dart';

part 'api_models.g.dart';

// NOTE: Since I can't run build_runner, I will write the generated code or use manual serialization for now 
// to ensure the user can at least see working code structure. 
// Actually, I'll write manual fromJson/toJson for maximum compatibility without running codegen immediately.

// -- Chat --

class ChatOut {
  final String reply;
  final int conversationId;

  ChatOut({required this.reply, required this.conversationId});

  factory ChatOut.fromJson(Map<String, dynamic> json) {
    return ChatOut(
      reply: json['reply'] as String,
      conversationId: json['conversation_id'] as int,
    );
  }
}

class TokenPair {
  final String accessToken;
  final String refreshToken;
  
  TokenPair({required this.accessToken, required this.refreshToken});
  
  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

enum MessageRole { user, assistant, system }

class MessageDTO {
  final int id;
  final MessageRole role;
  final String? text;
  final DateTime? createdAt;
  final List<String>? imageUrls;
  
  MessageDTO({
    required this.id,
    required this.role,
    this.text,
    this.createdAt,
    this.imageUrls,
  });
  
  factory MessageDTO.fromJson(Map<String, dynamic> json) {
    return MessageDTO(
      id: json['id'] as int,
      role: MessageRole.values.firstWhere((e) => e.toString().split('.').last == json['role'], orElse: () => MessageRole.user),
      text: json['text'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      imageUrls: (json['image_urls'] as List?)?.map((e) => e as String).toList(),
    );
  }
}

class ConversationSummary {
  final int id;
  final String? title;
  final DateTime? updatedAt;
  final int? messageCount;
  
  ConversationSummary({required this.id, this.title, this.updatedAt, this.messageCount});
  
  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as int,
      title: json['title'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      messageCount: json['message_count'] as int?,
    );
  }
}

class ConversationListResponse {
  final List<ConversationSummary> conversations;
  final int? total;
  
  ConversationListResponse({required this.conversations, this.total});
  
  factory ConversationListResponse.fromJson(Map<String, dynamic> json) {
    // Check if 'conversations' key exists or strict list
    // iOS code expected { conversations: [...], total: ... }
    return ConversationListResponse(
      conversations: (json['conversations'] as List)
          .map((e) => ConversationSummary.fromJson(e))
          .toList(),
      total: json['total'] as int?,
    );
  }
}

class ConversationMessagesResponse {
  final int conversationId;
  final List<MessageDTO> messages;
  final int total;
  
  ConversationMessagesResponse({required this.conversationId, required this.messages, required this.total});
  
  factory ConversationMessagesResponse.fromJson(Map<String, dynamic> json) {
    return ConversationMessagesResponse(
      conversationId: json['conversationId'] ?? 0, // Sometimes backend might not send it in wrapper
      messages: (json['messages'] as List).map((e) => MessageDTO.fromJson(e)).toList(),
      total: json['total'] as int? ?? 0,
    );
  }
}
