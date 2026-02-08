import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:salom_ai/core/api/token_store.dart';
import 'package:salom_ai/core/constants/config.dart';

enum RealtimeConnectionState { disconnected, connecting, connected, error }

class RealtimeFrame {
  final String type;
  final String? text;
  final String? state;
  final String? error;
  final Uint8List? audioData;

  RealtimeFrame({
    required this.type,
    this.text,
    this.state,
    this.error,
    this.audioData,
  });
}

class RealtimeWebSocketManager {
  WebSocketChannel? _channel;
  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  RealtimeConnectionState get state => _state;

  final _frameController = StreamController<RealtimeFrame>.broadcast();
  Stream<RealtimeFrame> get frames => _frameController.stream;

  final _stateController = StreamController<RealtimeConnectionState>.broadcast();
  Stream<RealtimeConnectionState> get stateStream => _stateController.stream;

  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  bool _intentionalDisconnect = false;

  Future<void> connect({String? language, String? voice, String? role}) async {
    if (_state == RealtimeConnectionState.connecting ||
        _state == RealtimeConnectionState.connected) return;

    _intentionalDisconnect = false;
    _setState(RealtimeConnectionState.connecting);

    try {
      final token = await TokenStore.shared.getAccessToken();
      if (token == null) {
        _setState(RealtimeConnectionState.error);
        return;
      }

      final params = <String, String>{
        'token': token,
        if (language != null) 'language': language,
        if (voice != null) 'voice': voice,
        if (role != null) 'role': role,
      };

      final queryStr = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final wsUrl = '${Config.apiBaseUrl.replaceFirst('https', 'wss')}/ws/voice/yandex/realtime?$queryStr';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (data) {
          if (data is String) {
            _handleJsonFrame(data);
          } else if (data is List<int>) {
            _frameController.add(RealtimeFrame(
              type: 'audio',
              audioData: Uint8List.fromList(data),
            ));
          }
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _handleDisconnect();
        },
      );

      _setState(RealtimeConnectionState.connected);
      _reconnectAttempts = 0;
      _startPing();
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
      _setState(RealtimeConnectionState.error);
      _attemptReconnect(language: language, voice: voice, role: role);
    }
  }

  void _handleJsonFrame(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String? ?? '';

      switch (type) {
        case 'connected':
          _setState(RealtimeConnectionState.connected);
          _frameController.add(RealtimeFrame(type: 'connected'));
          break;
        case 'state':
          _frameController.add(RealtimeFrame(type: 'state', state: json['state'] as String?));
          break;
        case 'transcription':
          _frameController.add(RealtimeFrame(type: 'transcription', text: json['text'] as String?));
          break;
        case 'ai_response':
          _frameController.add(RealtimeFrame(type: 'ai_response', text: json['text'] as String?));
          break;
        case 'error':
          _frameController.add(RealtimeFrame(type: 'error', error: json['message'] as String? ?? json['error'] as String?));
          break;
        default:
          _frameController.add(RealtimeFrame(type: type, text: json['text'] as String?));
      }
    } catch (e) {
      debugPrint('Failed to parse WS frame: $e');
    }
  }

  void sendAudioChunk(Uint8List data) {
    _channel?.sink.add(data);
  }

  void sendControl(String type, {Map<String, dynamic>? extra}) {
    final msg = {'type': type, ...?extra};
    _channel?.sink.add(jsonEncode(msg));
  }

  void sendSpeechStarted() => sendControl('speech_started');
  void sendEndUtterance() => sendControl('end_utterance');
  void sendInterrupt() => sendControl('interrupt');
  void sendReset() => sendControl('reset');

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sendControl('ping');
    });
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    if (!_intentionalDisconnect) {
      _setState(RealtimeConnectionState.disconnected);
      _attemptReconnect();
    }
  }

  void _attemptReconnect({String? language, String? voice, String? role}) {
    if (_intentionalDisconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setState(RealtimeConnectionState.error);
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);
    Future.delayed(delay, () {
      if (!_intentionalDisconnect) {
        connect(language: language, voice: voice, role: role);
      }
    });
  }

  void _setState(RealtimeConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(RealtimeConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _frameController.close();
    _stateController.close();
  }
}
