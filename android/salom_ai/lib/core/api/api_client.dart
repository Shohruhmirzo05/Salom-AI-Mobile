import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/constants/config.dart';
import 'package:salom_ai/core/api/token_store.dart';
import 'package:salom_ai/core/api/api_models.dart';

final apiClientProvider = Provider((ref) => ApiClient(ref));

class ApiClient {
  final Ref _ref;
  late final Dio _dio;
  final _httpClient = http.Client();
  
  ApiClient(this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: Config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStore.shared.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        print('➡️ [API] ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('⬅️ [API] ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print('❌ [API Error] ${e.message}');
        if (e.response?.statusCode == 401) {
          final refreshToken = await TokenStore.shared.getRefreshToken();
          if (refreshToken != null) {
            try {
              final newTokens = await _refreshAccessToken(refreshToken);
              await TokenStore.shared.saveTokens(newTokens.accessToken, newTokens.refreshToken);
              e.requestOptions.headers['Authorization'] = 'Bearer ${newTokens.accessToken}';
              final response = await _dio.request(
                e.requestOptions.path,
                options: Options(
                  method: e.requestOptions.method,
                  headers: e.requestOptions.headers,
                  responseType: e.requestOptions.responseType,
                ),
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
              );
              return handler.resolve(response);
            } catch (authError) {
              await TokenStore.shared.clear();
              return handler.next(e);
            }
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<TokenPair> _refreshAccessToken(String refreshToken) async {
    final dioRefresh = Dio(BaseOptions(baseUrl: Config.apiBaseUrl));
    final response = await dioRefresh.post('/auth/refresh', data: {'refresh_token': refreshToken});
    return TokenPair.fromJson(response.data);
  }

  Future<void> verifyOtp(String phone, String code) async {
    final response = await _dio.post('/auth/verify-otp', data: {'phone': phone, 'code': code});
    final tokens = TokenPair.fromJson(response.data);
    await TokenStore.shared.saveTokens(tokens.accessToken, tokens.refreshToken);
  }

  Future<TokenPair> oauthVerify(String token) async {
    final response = await _dio.post('/auth/oauth/verify', data: {'access_token': token});
    return TokenPair.fromJson(response.data);
  }

  Future<OAuthUser> getMe() async {
    final response = await _dio.get('/auth/me');
    return OAuthUser.fromJson(response.data);
  }

  Stream<ChatStreamEvent> streamChatMessage(String text, {int? conversationId, String? model, List<String>? attachments}) async* {
    final url = Uri.parse('${Config.apiBaseUrl}/chat/stream');
    final accessToken = await TokenStore.shared.getAccessToken();
    
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    
    request.body = jsonEncode({
      'text': text,
      if (conversationId != null && conversationId != 0) 'conversation_id': conversationId,
      if (model != null) 'model': model,
      if (attachments != null) 'attachments': attachments,
    });

    try {
      print('➡️ [API-HTTP-Stream] POST ${url.path}');
      final response = await _httpClient.send(request);
      
      if (response.statusCode == 401) {
        final refreshToken = await TokenStore.shared.getRefreshToken();
        if (refreshToken != null) {
          final newTokens = await _refreshAccessToken(refreshToken);
          await TokenStore.shared.saveTokens(newTokens.accessToken, newTokens.refreshToken);
          yield* streamChatMessage(text, conversationId: conversationId, model: model, attachments: attachments);
          return;
        }
      }

      final stream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

      await for (final line in stream) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        print('📡 SSE Line: $trimmedLine');

        if (trimmedLine.startsWith('data:')) {
          final jsonStr = trimmedLine.substring(5).trim();
          if (jsonStr == "[DONE]") continue;
          try {
            final Map<String, dynamic> json = jsonDecode(jsonStr);
            yield ChatStreamEvent.fromJson(json);
          } catch (e) {
            print("❌ Failed to parse SSE JSON: $jsonStr Error: $e");
          }
        }
      }
    } catch (e) {
      print('❌ [API-HTTP-Stream Error] $e');
      rethrow;
    }
  }

  Future<ChatOut> sendChatMessage(String text, {int? conversationId, String? model, int? projectId, List<String>? attachments}) async {
    final data = {
      'text': text,
      if (conversationId != null) 'conversation_id': conversationId,
      if (model != null) 'model': model,
      if (projectId != null) 'project_id': projectId,
      if (attachments != null) 'attachments': attachments,
    };
    final response = await _dio.post('/chat', data: data);
    return ChatOut.fromJson(response.data);
  }

  Future<List<ConversationSummary>> listConversations({int limit = 20, int offset = 0}) async {
    final response = await _dio.get('/conversations', queryParameters: {'limit': limit, 'offset': offset});
    return ConversationListResponse.fromJson(response.data).conversations;
  }

  Future<List<MessageDTO>> getConversationMessages(int id) async {
    final response = await _dio.get('/conversations/$id/messages');
    return ConversationMessagesResponse.fromJson(response.data).messages;
  }

  Future<List<SubscriptionPlan>> listPlans() async {
    final response = await _dio.get('/subscriptions/plans');
    return (response.data as List).map((e) => SubscriptionPlan.fromJson(e)).toList();
  }

  Future<CurrentSubscriptionResponse> currentSubscription() async {
    final response = await _dio.get('/subscriptions/current');
    return CurrentSubscriptionResponse.fromJson(response.data);
  }

  Future<SubscribeResponse> subscribe(String plan, String provider) async {
    final response = await _dio.post('/subscriptions/subscribe', data: {'plan': plan, 'provider': provider});
    return SubscribeResponse.fromJson(response.data);
  }

  Future<OAuthUser> updateProfile({String? language, String? displayName}) async {
    final data = {if (language != null) 'language': language, if (displayName != null) 'display_name': displayName};
    final response = await _dio.put('/auth/me', data: data);
    return OAuthUser.fromJson(response.data);
  }

  Future<StatusMessageResponse> deleteAccount() async {
    final response = await _dio.delete('/account');
    return StatusMessageResponse.fromJson(response.data);
  }

  Future<FeedbackResponse> sendFeedback(String content) async {
    final response = await _dio.post('/feedback', data: {'content': content, 'platform': 'android'});
    return FeedbackResponse.fromJson(response.data);
  }
}
