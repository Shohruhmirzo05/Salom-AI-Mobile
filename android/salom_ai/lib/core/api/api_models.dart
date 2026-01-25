import 'package:json_annotation/json_annotation.dart';

// part 'api_models.g.dart';

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

class SearchResult {
  final String? title;
  final String? url;
  final String? date;

  SearchResult({this.title, this.url, this.date});

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] as String?,
      url: json['url'] as String?,
      date: json['date'] as String?,
    );
  }
}

class MessageDTO {
  final int id;
  final MessageRole role;
  final String? text;
  final DateTime? createdAt;
  final List<String>? imageUrls;
  final List<SearchResult>? searchResults;
  final String? perplexityModel;
  final List<String>? fileUrls;
  final String? audioUrl;
  
  MessageDTO({
    required this.id,
    required this.role,
    this.text,
    this.createdAt,
    this.imageUrls,
    this.searchResults,
    this.perplexityModel,
    this.fileUrls,
    this.audioUrl,
  });
  
  factory MessageDTO.fromJson(Map<String, dynamic> json) {
    return MessageDTO(
      id: json['id'] as int,
      role: MessageRole.values.firstWhere((e) => e.toString().split('.').last == json['role'], orElse: () => MessageRole.user),
      text: json['text'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      imageUrls: (json['image_urls'] as List?)?.map((e) => e as String).toList(),
      searchResults: (json['search_results'] as List?)?.map((e) => SearchResult.fromJson(e)).toList(),
      perplexityModel: json['perplexity_model'] as String?,
      fileUrls: (json['file_urls'] as List?)?.map((e) => e as String).toList(),
      audioUrl: json['audio_url'] as String?,
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
  
  factory ConversationListResponse.fromJson(dynamic json) {
    if (json is List) {
      return ConversationListResponse(
        conversations: json.map((e) => ConversationSummary.fromJson(e)).toList(),
        total: json.length,
      );
    }
    
    final map = json as Map<String, dynamic>;
    return ConversationListResponse(
      conversations: (map['conversations'] as List)
          .map((e) => ConversationSummary.fromJson(e))
          .toList(),
      total: map['total'] as int?,
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
      conversationId: json['conversation_id'] ?? 0,
      messages: (json['messages'] as List?)?.map((e) => MessageDTO.fromJson(e)).toList() ?? [],
      total: json['total'] as int? ?? 0,
    );
  }
}

class OAuthUser {
  final int id;
  final String? email;
  final String? displayName;
  final String? authProvider;
  final DateTime? createdAt;
  
  OAuthUser({required this.id, this.email, this.displayName, this.authProvider, this.createdAt});
  
  factory OAuthUser.fromJson(Map<String, dynamic> json) {
    return OAuthUser(
      id: json['id'] as int,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      authProvider: json['auth_provider'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

class StatusMessageResponse {
  final String? detail;
  StatusMessageResponse({this.detail});
  factory StatusMessageResponse.fromJson(Map<String, dynamic> json) => StatusMessageResponse(detail: json['detail'] as String?);
}

class SubscriptionPlan {
  final String code;
  final String name;
  final int priceUzs;
  final int? monthlyMessages;
  final int? monthlyTokens;
  final List<Map<String, String>>? benefits;

  SubscriptionPlan({
    required this.code,
    required this.name,
    required this.priceUzs,
    this.monthlyMessages,
    this.monthlyTokens,
    this.benefits,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      code: json['code'] as String,
      name: json['name'] as String,
      priceUzs: json['price_uzs'] as int,
      monthlyMessages: json['monthly_messages'] as int?,
      monthlyTokens: json['monthly_tokens'] as int?,
      benefits: (json['benefits'] as List?)
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList(),
    );
  }
}

class CurrentSubscriptionResponse {
  final String? plan;
  final bool active;
  final DateTime? startedAt;
  final DateTime? expiresAt;

  CurrentSubscriptionResponse({this.plan, required this.active, this.startedAt, this.expiresAt});

  factory CurrentSubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return CurrentSubscriptionResponse(
      plan: json['plan'] as String?,
      active: json['active'] as bool,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
    );
  }
}

class SubscribeResponse {
  final String? provider;
  final int? amountUzs;
  final String? status;
  final String? checkoutUrl;

  SubscribeResponse({this.provider, this.amountUzs, this.status, this.checkoutUrl});

  factory SubscribeResponse.fromJson(Map<String, dynamic> json) {
    return SubscribeResponse(
      provider: json['provider'] as String?,
      amountUzs: json['amount_uzs'] as int?,
      status: json['status'] as String?,
      checkoutUrl: json['checkout_url'] as String?,
    );
  }
}

class FeedbackResponse {
  final int id;
  final String content;

  FeedbackResponse({required this.id, required this.content});

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) {
    return FeedbackResponse(
      id: json['id'] as int,
      content: json['content'] as String,
    );
  }
}
