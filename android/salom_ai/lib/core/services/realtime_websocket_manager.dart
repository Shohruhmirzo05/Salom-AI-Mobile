import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:salom_ai/core/api/token_store.dart';
import 'package:salom_ai/core/constants/config.dart';

enum RealtimeConnectionState { disconnected, connecting, connected, error }

class RealtimeFrame {
  final String type;
  final String? text;
  final String? state;
  final String? error;
  final String? language;
  final Uint8List? audioData;

  RealtimeFrame({
    required this.type,
    this.text,
    this.state,
    this.error,
    this.language,
    this.audioData,
  });
}

/// Manages the realtime voice WebSocket lifecycle.
///
/// Parity with the production iOS implementation in
/// `RealtimeWebSocketManager.swift` — protocol + app pings every 15s,
/// token refresh before connect, mid-call language switching,
/// graceful disconnect on app background, exponential backoff,
/// and stale-callback guards on reconnect.
class RealtimeWebSocketManager with WidgetsBindingObserver {
  WebSocketChannel? _channel;
  WebSocket? _rawSocket;
  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  RealtimeConnectionState get state => _state;

  final _frameController = StreamController<RealtimeFrame>.broadcast();
  Stream<RealtimeFrame> get frames => _frameController.stream;

  final _stateController = StreamController<RealtimeConnectionState>.broadcast();
  Stream<RealtimeConnectionState> get stateStream => _stateController.stream;

  Timer? _appPingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _maxBackoff = Duration(seconds: 30);
  bool _intentionalDisconnect = false;
  bool _isConnecting = false;
  bool _wasConnectedBeforeBackground = false;
  bool _lifecycleObserved = false;

  // Current session settings (so reconnect uses the latest values, not stale closure args)
  String? _language;
  String? _voice;
  String? _role;

  // Token refresher injected from outside so we don't import api_client here
  Future<void> Function()? _refreshAccessToken;

  RealtimeWebSocketManager({Future<void> Function()? refreshAccessToken}) {
    _refreshAccessToken = refreshAccessToken;
  }

  /// Update settings without reconnecting. Sends `config_update` so the
  /// backend can rebuild the system prompt with the new locale.
  void changeLanguage(String language, {String? voice, String? role}) {
    _language = language;
    if (voice != null) _voice = voice;
    if (role != null) _role = role;
    if (_state != RealtimeConnectionState.connected) {
      debugPrint('ℹ️ [RealtimeWS] changeLanguage queued — not connected yet');
      return;
    }
    sendControl('config_update', extra: {
      'data': {
        'language': _language,
        if (_voice != null) 'voice': _voice,
        if (_role != null) 'role': _role,
      }
    });
  }

  Future<void> connect({String? language, String? voice, String? role}) async {
    // Guard against concurrent / duplicate connects (StrictMode / fast re-entry).
    if (_isConnecting ||
        _state == RealtimeConnectionState.connecting ||
        _state == RealtimeConnectionState.connected) {
      debugPrint('🔌 [RealtimeWS] connect() skipped — already in progress');
      return;
    }
    _isConnecting = true;
    _intentionalDisconnect = false;

    // Persist settings for reconnect
    if (language != null) _language = language;
    if (voice != null) _voice = voice;
    if (role != null) _role = role;

    // Wire app lifecycle observer once
    if (!_lifecycleObserved) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserved = true;
    }

    _setState(RealtimeConnectionState.connecting);

    // Refresh the access token before connecting so a stale JWT never reaches the server.
    if (_refreshAccessToken != null) {
      try {
        await _refreshAccessToken!.call();
      } catch (e) {
        debugPrint('⚠️ [RealtimeWS] Token refresh failed — using cached: $e');
      }
    }

    try {
      final token = await TokenStore.shared.getAccessToken();
      if (token == null || token.isEmpty) {
        _isConnecting = false;
        _setState(RealtimeConnectionState.error);
        return;
      }

      final params = <String, String>{
        'token': token,
        if (_language != null) 'language': _language!,
        if (_voice != null) 'voice': _voice!,
        if (_role != null) 'role': _role!,
      };

      final queryStr = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final wsUrl =
          '${Config.apiBaseUrl.replaceFirst('https', 'wss')}/ws/voice/yandex/realtime?$queryStr';

      // Use raw WebSocket.connect so we can set the protocol-level pingInterval.
      // 15s aligns with iOS and survives carrier NAT idle timeouts.
      final socket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('WS connect timed out'),
      );
      socket.pingInterval = const Duration(seconds: 15);
      _rawSocket = socket;

      final channel = IOWebSocketChannel(socket);
      _channel = channel;

      // Capture this channel so a stale listen callback from a previous socket
      // cannot mutate state on a newer connection.
      final WebSocketChannel activeChannel = channel;

      channel.stream.listen(
        (data) {
          if (!identical(_channel, activeChannel)) return; // stale frame
          if (data is String) {
            _handleJsonFrame(data);
          } else if (data is List<int>) {
            _frameController.add(RealtimeFrame(
              type: 'audio',
              audioData: data is Uint8List ? data : Uint8List.fromList(data),
            ));
          }
        },
        onDone: () {
          if (!identical(_channel, activeChannel)) return;
          final closeCode = channel.closeCode;
          debugPrint('🔌 [RealtimeWS] Closed: code=$closeCode reason=${channel.closeReason}');
          _handleClose(closeCode);
        },
        onError: (Object error, StackTrace st) {
          if (!identical(_channel, activeChannel)) return;
          debugPrint('❌ [RealtimeWS] Stream error: $error');
          _handleClose(null);
        },
        cancelOnError: true,
      );

      _isConnecting = false;
      _setState(RealtimeConnectionState.connected);
      _reconnectAttempts = 0;
      _startAppPing();
    } catch (e) {
      _isConnecting = false;
      debugPrint('❌ [RealtimeWS] connect error: $e');
      _setState(RealtimeConnectionState.error);
      _attemptReconnect();
    }
  }

  void _handleJsonFrame(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = (json['type'] as String?) ?? '';
      final inner = (json['data'] is Map<String, dynamic>)
          ? json['data'] as Map<String, dynamic>
          : null;

      switch (type) {
        case 'connected':
          _setState(RealtimeConnectionState.connected);
          _frameController.add(RealtimeFrame(type: 'connected'));
          break;
        case 'state':
          _frameController.add(RealtimeFrame(
            type: 'state',
            state: (inner?['state'] ?? json['state']) as String?,
          ));
          break;
        case 'transcription':
          _frameController.add(RealtimeFrame(
            type: 'transcription',
            text: (inner?['text'] ?? json['text']) as String?,
          ));
          break;
        case 'ai_response':
          _frameController.add(RealtimeFrame(
            type: 'ai_response',
            text: (inner?['text'] ?? json['text']) as String?,
          ));
          break;
        case 'error':
          _frameController.add(RealtimeFrame(
            type: 'error',
            error: (inner?['message'] ?? json['message'] ?? json['error']) as String?,
          ));
          break;
        case 'config_update':
          final lang = (inner?['language'] ?? json['language']) as String?;
          if (lang != null) _language = lang;
          _frameController.add(RealtimeFrame(type: 'config_update', language: lang));
          break;
        case 'pong':
        case 'ping':
          // Ignore — handled at transport layer
          break;
        default:
          _frameController.add(RealtimeFrame(type: type, text: json['text'] as String?));
      }
    } catch (e) {
      debugPrint('⚠️ [RealtimeWS] Failed to parse frame: $e');
    }
  }

  void sendAudioChunk(Uint8List data) {
    if (_state != RealtimeConnectionState.connected) return;
    try {
      _channel?.sink.add(data);
    } catch (e) {
      debugPrint('⚠️ [RealtimeWS] sendAudioChunk failed: $e');
    }
  }

  void sendControl(String type, {Map<String, dynamic>? extra}) {
    if (_channel == null) return;
    try {
      final msg = {'type': type, ...?extra};
      _channel!.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('⚠️ [RealtimeWS] sendControl($type) failed: $e');
    }
  }

  void sendSpeechStarted() => sendControl('speech_started');
  void sendEndUtterance() => sendControl('end_utterance');
  void sendInterrupt() => sendControl('interrupt');
  void sendReset() => sendControl('reset');

  void _startAppPing() {
    _appPingTimer?.cancel();
    // Protocol-level pings are handled by WebSocket.pingInterval (15s).
    // App-level ping is informational so the backend's heartbeat watcher stays happy.
    _appPingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_state != RealtimeConnectionState.connected) return;
      sendControl('ping', extra: {
        'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
      });
    });
  }

  void _handleClose(int? closeCode) {
    _appPingTimer?.cancel();
    _appPingTimer = null;
    _channel = null;
    _rawSocket = null;

    if (_intentionalDisconnect) {
      _setState(RealtimeConnectionState.disconnected);
      return;
    }

    _setState(RealtimeConnectionState.disconnected);

    // Skip auto-reconnect on:
    //   1000 = normal closure
    //   1001 = going away (our intentional disconnect uses this)
    //   1008 = policy violation (auth failure)
    if (closeCode == 1000 || closeCode == 1001 || closeCode == 1008) {
      debugPrint('🔌 [RealtimeWS] Clean close (code=$closeCode) — not reconnecting');
      return;
    }

    _attemptReconnect();
  }

  void _attemptReconnect() {
    if (_intentionalDisconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ [RealtimeWS] Max reconnect attempts reached');
      _setState(RealtimeConnectionState.error);
      return;
    }
    _reconnectAttempts++;
    // Exponential backoff with cap (mirrors iOS: 1, 2, 4, 8, 16, capped at 30).
    final secs = math.min(math.pow(2, _reconnectAttempts).toInt(), _maxBackoff.inSeconds);
    final delay = Duration(seconds: secs);
    debugPrint('🔄 [RealtimeWS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!_intentionalDisconnect) {
        connect();
      }
    });
  }

  void _setState(RealtimeConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  /// User-initiated disconnect — closes cleanly with 1001 so reconnect logic
  /// recognises it as intentional.
  void disconnect() {
    _intentionalDisconnect = true;
    _appPingTimer?.cancel();
    _appPingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      // 1001 = going away (matches iOS .goingAway)
      _channel?.sink.close(1001, 'User disconnected');
    } catch (_) {}
    _channel = null;
    _rawSocket = null;
    _setState(RealtimeConnectionState.disconnected);
    _reconnectAttempts = 0;
  }

  // App lifecycle — disconnect cleanly on background, reconnect on foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    switch (appState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _wasConnectedBeforeBackground = _state == RealtimeConnectionState.connected ||
            _state == RealtimeConnectionState.connecting;
        if (_wasConnectedBeforeBackground) {
          debugPrint('📱 [RealtimeWS] App backgrounded — disconnecting WS');
          disconnect();
        }
        break;
      case AppLifecycleState.resumed:
        if (_wasConnectedBeforeBackground) {
          debugPrint('📱 [RealtimeWS] App foregrounded — reconnecting WS');
          _wasConnectedBeforeBackground = false;
          // Trigger a clean reconnect (resets intentional flag inside connect()).
          connect(language: _language, voice: _voice, role: _role);
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void dispose() {
    disconnect();
    if (_lifecycleObserved) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserved = false;
    }
    _frameController.close();
    _stateController.close();
  }
}
