import 'package:json_annotation/json_annotation.dart';

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

class ChatStreamEvent {
  final String type;
  final String? content;
  final int? conversationId;
  final String? message;

  ChatStreamEvent({required this.type, this.content, this.conversationId, this.message});

  factory ChatStreamEvent.fromJson(Map<String, dynamic> json) {
    return ChatStreamEvent(
      type: json['type'] as String,
      content: json['content'] as String?,
      conversationId: json['conversation_id'] as int?,
      message: json['message'] as String?,
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

// -- AI Models --

class AIModel {
  final String id;
  final String name;
  final String? tier;
  final bool vision;
  final int? limit;
  final int? usage;

  AIModel({
    required this.id,
    required this.name,
    this.tier,
    this.vision = false,
    this.limit,
    this.usage,
  });

  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      id: json['id'] as String? ?? json['model_id'] as String? ?? '',
      name: json['name'] as String? ?? json['display_name'] as String? ?? '',
      tier: json['tier'] as String?,
      vision: json['vision'] as bool? ?? json['supports_vision'] as bool? ?? false,
      limit: json['limit'] as int? ?? json['daily_limit'] as int?,
      usage: json['usage'] as int? ?? json['daily_usage'] as int?,
    );
  }
}

// -- Search --

class MessageSearchHit {
  final int conversationId;
  final String? conversationTitle;
  final int messageId;
  final String? text;
  final String? role;

  MessageSearchHit({
    required this.conversationId,
    this.conversationTitle,
    required this.messageId,
    this.text,
    this.role,
  });

  factory MessageSearchHit.fromJson(Map<String, dynamic> json) {
    return MessageSearchHit(
      conversationId: json['conversation_id'] as int,
      conversationTitle: json['conversation_title'] as String?,
      messageId: json['message_id'] as int? ?? json['id'] as int? ?? 0,
      text: json['text'] as String?,
      role: json['role'] as String?,
    );
  }
}

class SearchResponse {
  final List<MessageSearchHit> results;
  final int total;

  SearchResponse({required this.results, this.total = 0});

  factory SearchResponse.fromJson(dynamic json) {
    if (json is List) {
      return SearchResponse(
        results: json.map((e) => MessageSearchHit.fromJson(e)).toList(),
        total: json.length,
      );
    }
    final map = json as Map<String, dynamic>;
    return SearchResponse(
      results: (map['results'] as List?)?.map((e) => MessageSearchHit.fromJson(e)).toList() ?? [],
      total: map['total'] as int? ?? 0,
    );
  }
}

// -- File Upload --

class FileUploadResponse {
  final String url;
  final String? fileId;
  final String? filename;

  FileUploadResponse({required this.url, this.fileId, this.filename});

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      url: json['url'] as String? ?? json['file_url'] as String? ?? '',
      fileId: json['file_id'] as String? ?? json['id']?.toString(),
      filename: json['filename'] as String? ?? json['name'] as String?,
    );
  }
}

// -- Image Generation --

class ImageGenerationResponse {
  final String? imageUrl;
  final String? status;
  final String? error;

  ImageGenerationResponse({this.imageUrl, this.status, this.error});

  factory ImageGenerationResponse.fromJson(Map<String, dynamic> json) {
    return ImageGenerationResponse(
      imageUrl: json['image_url'] as String? ?? json['url'] as String?,
      status: json['status'] as String?,
      error: json['error'] as String?,
    );
  }
}

// -- Usage Stats --

class UsageStatsResponse {
  final PlanInfo? plan;
  final UsageLimits? limits;
  final UsageData? usage;

  UsageStatsResponse({this.plan, this.limits, this.usage});

  factory UsageStatsResponse.fromJson(Map<String, dynamic> json) {
    return UsageStatsResponse(
      plan: json['plan'] != null ? PlanInfo.fromJson(json['plan']) : null,
      limits: json['limits'] != null ? UsageLimits.fromJson(json['limits']) : null,
      usage: json['usage'] != null ? UsageData.fromJson(json['usage']) : null,
    );
  }
}

class PlanInfo {
  final String name;
  final String code;
  final bool isPro;

  PlanInfo({required this.name, required this.code, this.isPro = false});

  factory PlanInfo.fromJson(Map<String, dynamic> json) {
    return PlanInfo(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      isPro: json['is_pro'] as bool? ?? false,
    );
  }
}

class UsageLimits {
  final int? messages;
  final int? images;
  final int? files;
  final int? voiceMinutes;

  UsageLimits({this.messages, this.images, this.files, this.voiceMinutes});

  factory UsageLimits.fromJson(Map<String, dynamic> json) {
    return UsageLimits(
      messages: json['messages'] as int?,
      images: json['images'] as int?,
      files: json['files'] as int?,
      voiceMinutes: json['voice_minutes'] as int?,
    );
  }
}

class UsageData {
  final int? messagesUsed;
  final int? imagesUsed;
  final int? filesUsed;
  final int? voiceMinutesUsed;
  final Map<String, int>? perModel;

  UsageData({this.messagesUsed, this.imagesUsed, this.filesUsed, this.voiceMinutesUsed, this.perModel});

  factory UsageData.fromJson(Map<String, dynamic> json) {
    return UsageData(
      messagesUsed: json['messages_used'] as int? ?? json['messages'] as int?,
      imagesUsed: json['images_used'] as int? ?? json['images'] as int?,
      filesUsed: json['files_used'] as int? ?? json['files'] as int?,
      voiceMinutesUsed: json['voice_minutes_used'] as int? ?? json['voice_minutes'] as int?,
      perModel: (json['per_model'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)),
    );
  }
}

// -- Voice STT --

class STTResponse {
  final String? text;
  final String? language;

  STTResponse({this.text, this.language});

  factory STTResponse.fromJson(Map<String, dynamic> json) {
    return STTResponse(
      text: json['text'] as String?,
      language: json['language'] as String?,
    );
  }
}
