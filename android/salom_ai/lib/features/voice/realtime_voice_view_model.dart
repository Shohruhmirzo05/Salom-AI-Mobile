import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/services/realtime_websocket_manager.dart';
import 'package:salom_ai/core/services/realtime_audio_manager.dart';

final realtimeVoiceProvider =
    StateNotifierProvider.autoDispose<RealtimeVoiceViewModel, RealtimeVoiceState>((ref) {
  return RealtimeVoiceViewModel();
});

class RealtimeVoiceState {
  final RealtimeConnectionState connectionState;
  final String? transcription;
  final String? aiResponse;
  final String? statusText;
  final double audioLevel;
  final bool isMuted;
  final String? error;

  RealtimeVoiceState({
    this.connectionState = RealtimeConnectionState.disconnected,
    this.transcription,
    this.aiResponse,
    this.statusText,
    this.audioLevel = 0.0,
    this.isMuted = false,
    this.error,
  });

  RealtimeVoiceState copyWith({
    RealtimeConnectionState? connectionState,
    String? transcription,
    String? aiResponse,
    String? statusText,
    double? audioLevel,
    bool? isMuted,
    String? error,
  }) {
    return RealtimeVoiceState(
      connectionState: connectionState ?? this.connectionState,
      transcription: transcription ?? this.transcription,
      aiResponse: aiResponse ?? this.aiResponse,
      statusText: statusText ?? this.statusText,
      audioLevel: audioLevel ?? this.audioLevel,
      isMuted: isMuted ?? this.isMuted,
      error: error,
    );
  }
}

class RealtimeVoiceViewModel extends StateNotifier<RealtimeVoiceState> {
  final RealtimeWebSocketManager _wsManager = RealtimeWebSocketManager();
  final RealtimeAudioManager _audioManager = RealtimeAudioManager();

  StreamSubscription? _frameSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _audioLevelSubscription;
  StreamSubscription? _recordSubscription;

  RealtimeVoiceViewModel() : super(RealtimeVoiceState());

  Future<void> start({String? language, String? voice, String? role}) async {
    final hasPermission = await _audioManager.requestPermission();
    if (!hasPermission) {
      state = state.copyWith(error: 'Microphone permission required');
      return;
    }

    state = state.copyWith(
      statusText: 'Ulanmoqda...',
      connectionState: RealtimeConnectionState.connecting,
    );

    _stateSubscription = _wsManager.stateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);
      if (connState == RealtimeConnectionState.connected) {
        state = state.copyWith(statusText: 'Gapiring...');
        _startAudioCapture();
      } else if (connState == RealtimeConnectionState.error) {
        state = state.copyWith(statusText: 'Xatolik yuz berdi');
      }
    });

    _frameSubscription = _wsManager.frames.listen(_handleFrame);

    _audioLevelSubscription = _audioManager.audioLevel.listen((level) {
      state = state.copyWith(audioLevel: level);
    });

    await _wsManager.connect(language: language, voice: voice, role: role);
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
      case 'processing':
        state = state.copyWith(statusText: 'Qayta ishlanmoqda...');
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
          // Voice detected
        }
      }
    });
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
    state = RealtimeVoiceState();
  }

  @override
  void dispose() {
    stop();
    _wsManager.dispose();
    _audioManager.dispose();
    super.dispose();
  }
}
