import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/constants/config.dart';
import 'package:salom_ai/core/api/token_store.dart';
import 'package:salom_ai/core/api/api_models.dart';

final apiClientProvider = Provider((ref) => ApiClient(ref));

class ApiClient {
  final Ref _ref;
  late final Dio _dio;
  
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
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Attach Access Token if available
        final token = await TokenStore.shared.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer \$token';
        }
        
        // Debug Log
        print('➡️ [API] \${options.method} \${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('⬅️ [API] \${response.statusCode} \${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print('❌ [API Error] \${e.message}');
        
        // Handle 401 Unauthorized (Refresh Token Logic)
        if (e.response?.statusCode == 401) {
          final refreshToken = await TokenStore.shared.getRefreshToken();
          if (refreshToken != null) {
            try {
              // Lock interceptor to prevent multiple refreshes
              _dio.lock();
              
              // Call refresh endpoint
              final newTokens = await _refreshAccessToken(refreshToken);
              await TokenStore.shared.saveTokens(newTokens.accessToken, newTokens.refreshToken);
              
              _dio.unlock();
              
              // Retry original request
              e.requestOptions.headers['Authorization'] = 'Bearer \${newTokens.accessToken}';
              final response = await _dio.request(
                e.requestOptions.path,
                options: Options(
                  method: e.requestOptions.method,
                  headers: e.requestOptions.headers,
                ),
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
              );
              return handler.resolve(response);
              
            } catch (authError) {
              _dio.unlock();
              // Logout if refresh fails
              await TokenStore.shared.clear();
              // Ideally trigger a global logout event here
              return handler.next(e);
            }
          }
        }
        return handler.next(e);
      },
    ));
  }
  
  // -- Auth --
  
  Future<TokenPair> _refreshAccessToken(String refreshToken) async {
    // Navigate around the interceptor to avoid loops (create a clean dio instance or specific ignore)
    // Simple way: Access the base dio without interceptors for this one, or just use a flag.
    // Here we make a raw request.
    final dioRefresh = Dio(BaseOptions(baseUrl: Config.apiBaseUrl));
    final response = await dioRefresh.post('/auth/refresh', data: {'refresh_token': refreshToken});
    return TokenPair.fromJson(response.data);
  }
  
  Future<void> verifyOtp(String phone, String code) async {
    final response = await _dio.post('/auth/verify-otp', data: {'phone': phone, 'code': code});
    final tokens = TokenPair.fromJson(response.data);
    await TokenStore.shared.saveTokens(tokens.accessToken, tokens.refreshToken);
  }
  
  // -- Chat --
  
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
    final response = await _dio.get('/conversations', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    // Assuming backend returns a list or a wrapped object. Based on iOS it was ConversationListResponse?
    // Let's assume list for now or check models.
    // Checking APIClient.swift: returns ConversationListResponse
    return ConversationListResponse.fromJson(response.data).conversations;
  }
  
  Future<List<MessageDTO>> getConversationMessages(int id) async {
    final response = await _dio.get('/conversations/\$id/messages');
    // Swift: /conversations/{id}/messages with limit/offset.
    // Swift returns: ConversationMessagesResponse
    return ConversationMessagesResponse.fromJson(response.data).messages;
  }
  
  // -- Other Methods (Porting as needed) --
}
