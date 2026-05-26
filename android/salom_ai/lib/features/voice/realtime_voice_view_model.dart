import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/token_store.dart';
import 'package:salom_ai/core/services/realtime_audio_manager.dart';
import 'package:salom_ai/core/services/realtime_websocket_manager.dart';

final realtimeVoiceProvider =
    StateNotifierProvider.autoDispose<RealtimeVoiceViewModel, RealtimeVoiceState>((ref) {
  return RealtimeVoiceViewModel(ref);
});

class RealtimeVoiceState {
  final RealtimeConnectionState connectionState;
  final String? transcription;
  final String? aiResponse;
  final String? statusText;
  final double audioLevel;
  final bool isMuted;
  final String? error;
  final String language;

  RealtimeVoiceState({
    this.connectionState = RealtimeConnectionState.disconnected,
    this.transcription,
    this.aiResponse,
    this.statusText,
    this.audioLevel = 0.0,
    this.isMuted = false,
    this.error,
    this.language = 'uz-UZ',
  });

  RealtimeVoiceState copyWith({
    RealtimeConnectionState? connectionState,
    String? transcription,
    String? aiResponse,
    String? statusText,
    double? audioLevel,
    bool? isMuted,
    String? error,
    String? language,
  }) {
    return RealtimeVoiceState(
      connectionState: connectionState ?? this.connectionState,
      transcription: transcription ?? this.transcription,
      aiResponse: aiResponse ?? this.aiResponse,
      statusText: statusText ?? this.statusText,
      audioLevel: audioLevel ?? this.audioLevel,
      isMuted: isMuted ?? this.isMuted,
      error: error,
      language: language ?? this.language,
    );
  }
}

class RealtimeVoiceViewModel extends StateNotifier<RealtimeVoiceState> {
  final Ref _ref;
  late final RealtimeWebSocketManager _wsManager;
  final RealtimeAudioManager _audioManager = RealtimeAudioManager();

  StreamSubscription? _frameSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _audioLevelSubscription;
  StreamSubscription? _recordSubscription;
  StreamSubscription? _interruptionSubscription;
  AudioSession? _audioSession;
  bool _wasRecordingBeforeInterruption = false;

  RealtimeVoiceViewModel(this._ref) : super(RealtimeVoiceState()) {
    _wsManager = RealtimeWebSocketManager(
      refreshAccessToken: () async {
        final refresh = await TokenStore.shared.getRefreshToken();
        if (refresh == null || refresh.isEmpty) return;
        // Trigger a refresh by hitting any authed endpoint via the api client.
        // api_client.dart already has a 401 retry interceptor that refreshes.
        // We can also call /auth/me to validate freshness preemptively.
        try {
          await _ref.read(apiClientProvider).getMe();
        } catch (_) {/* swallow — connect() will surface the auth issue */}
      },
    );
  }

  Future<void> start({String? language, String? voice, String? role}) async {
    final hasPermission = await _audioManager.requestPermission();
    if (!hasPermission) {
      state = state.copyWith(error: 'Microphone permission required');
      return;
    }

    // Configure audio session so we play through speaker, duck other audio, and
    // observe interruptions (phone calls, alarms, voice assistants).
    await _setupAudioSession();

    state = state.copyWith(
      statusText: 'Ulanmoqda...',
      connectionState: RealtimeConnectionState.connecting,
      language: language ?? state.language,
    );

    _stateSubscription = _wsManager.stateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);
      if (connState == RealtimeConnectionState.connected) {
        state = state.copyWith(statusText: 'Gapiring...');
        _startAudioCapture();
      } else if (connState == RealtimeConnectionState.error) {
        state = state.copyWith(statusText: 'Xatolik yuz berdi');
      } else if (connState == RealtimeConnectionState.disconnected) {
        _recordSubscription?.cancel();
      }
    });

    _frameSubscription = _wsManager.frames.listen(_handleFrame);

    _audioLevelSubscription = _audioManager.audioLevel.listen((level) {
      state = state.copyWith(audioLevel: level);
    });

    await _wsManager.connect(language: language, voice: voice, role: role);
  }

  Future<void> _setupAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      _audioSession = session;

      _interruptionSubscription = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          debugPrint('🔕 [RealtimeVM] Audio interrupted — pausing');
          _wasRecordingBeforeInterruption = true;
          _recordSubscription?.pause();
          _audioManager.stopPlayback();
        } else {
          // Interruption ended
          if (event.type == AudioInterruptionType.pause && _wasRecordingBeforeInterruption) {
            debugPrint('🔔 [RealtimeVM] Interruption ended — resuming');
            _wasRecordingBeforeInterruption = false;
            _recordSubscription?.resume();
          } else {
            _wasRecordingBeforeInterruption = false;
          }
        }
      });
    } catch (e) {
      debugPrint('⚠️ [RealtimeVM] Audio session config failed: $e');
    }
  }

  void _handleFrame(RealtimeFrame frame) {
    switch (frame.type) {
      case 'transcription':
        state = state.copyWith(
          transcription: frame.text,
          statusText: 'Eshitilmoqda...',
        );
        break;
      case 'ai_response':
        state = state.copyWith(
          aiResponse: frame.text,
          statusText: 'Javob berilmoqda...',
        );
        break;
      case 'audio':
        if (frame.audioData != null) {
          _audioManager.playAudioBytes(frame.audioData!);
        }
        break;
      case 'state':
        _updateStatusFromState(frame.state);
        break;
      case 'config_update':
        if (frame.language != null) {
          state = state.copyWith(language: frame.language);
        }
        break;
      case 'error':
        state = state.copyWith(error: frame.error, statusText: 'Xatolik');
        break;
    }
  }

  void _updateStatusFromState(String? wsState) {
    switch (wsState) {
      case 'listening':
        state = state.copyWith(statusText: 'Gapiring...');
        break;
      case 'transcribing':
        state = state.copyWith(statusText: 'Yozilmoqda...');
        break;
      case 'thinking':
      case 'processing':
        state = state.copyWith(statusText: 'O\'ylanmoqda...');
        break;
      case 'speaking':
        state = state.copyWith(statusText: 'Javob berilmoqda...');
        break;
    }
  }

  Future<void> _startAudioCapture() async {
    final stream = await _audioManager.startRecording();
    if (stream == null) return;

    _recordSubscription = stream.listen((chunk) {
      if (!state.isMuted) {
        _wsManager.sendAudioChunk(chunk);

        final rms = _audioManager.calculateRMS(chunk);
        if (_audioManager.isVoiceActive(rms)) {
          // Voice detected — placeholder for future client VAD signalling
        }
      }
    });
  }

  /// Switch language mid-call without reconnecting.
  void changeLanguage(String language, {String? voice, String? role}) {
    state = state.copyWith(language: language);
    _wsManager.changeLanguage(language, voice: voice, role: role);
  }

  void toggleMute() {
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void interrupt() {
    _wsManager.sendInterrupt();
    _audioManager.stopPlayback();
  }

  Future<void> stop() async {
    _recordSubscription?.cancel();
    await _audioManager.stopRecording();
    await _audioManager.stopPlayback();
    _wsManager.disconnect();
    _frameSubscription?.cancel();
    _stateSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    _interruptionSubscription?.cancel();
    try {
      await _audioSession?.setActive(false);
    } catch (_) {}
    state = RealtimeVoiceState();
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _stateSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    _interruptionSubscription?.cancel();
    _recordSubscription?.cancel();
    _wsManager.dispose();
    _audioManager.dispose();
    super.dispose();
  }
}
