import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class RealtimeAudioManager {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // VAD parameters
  static const double _silenceThreshold = 0.03;
  static const Duration _silenceDuration = Duration(milliseconds: 1200);
  static const Duration _minSpeechDuration = Duration(milliseconds: 100);

  DateTime? _speechStartTime;
  DateTime? _lastSoundTime;

  final _audioLevelController = StreamController<double>.broadcast();
  Stream<double> get audioLevel => _audioLevelController.stream;

  StreamSubscription? _amplitudeSubscription;

  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  Future<Stream<Uint8List>?> startRecording() async {
    if (_isRecording) return null;

    final hasPermission = await requestPermission();
    if (!hasPermission) return null;

    _isRecording = true;
    _speechStartTime = null;
    _lastSoundTime = null;

    try {
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ));

      // Start amplitude monitoring
      _startAmplitudeMonitoring();

      return stream;
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      _isRecording = false;
      return null;
    }
  }

  void _startAmplitudeMonitoring() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = Stream.periodic(const Duration(milliseconds: 100)).listen((_) async {
      if (!_isRecording) return;
      try {
        final amplitude = await _recorder.getAmplitude();
        final normalized = _normalizeAmplitude(amplitude.current);
        _audioLevelController.add(normalized);
      } catch (_) {}
    });
  }

  double _normalizeAmplitude(double dbValue) {
    // Convert dB to 0-1 range. Typical values: -160 (silence) to 0 (max)
    final clamped = dbValue.clamp(-60.0, 0.0);
    return (clamped + 60.0) / 60.0;
  }

  double calculateRMS(Uint8List audioData) {
    if (audioData.isEmpty) return 0.0;
    final samples = audioData.buffer.asInt16List();
    double sumSquares = 0;
    for (final sample in samples) {
      sumSquares += sample * sample;
    }
    return sqrt(sumSquares / samples.length) / 32768.0;
  }

  bool isVoiceActive(double rms) {
    if (rms > _silenceThreshold) {
      _speechStartTime ??= DateTime.now();
      _lastSoundTime = DateTime.now();
      return true;
    }

    if (_lastSoundTime != null) {
      final silenceTime = DateTime.now().difference(_lastSoundTime!);
      if (silenceTime < _silenceDuration) return true;
    }

    return false;
  }

  bool hasSufficientSpeech() {
    if (_speechStartTime == null) return false;
    return DateTime.now().difference(_speechStartTime!) > _minSpeechDuration;
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    _amplitudeSubscription?.cancel();
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> playAudioBytes(Uint8List data) async {
    try {
      _isPlaying = true;
      await _player.play(BytesSource(data));
      _player.onPlayerComplete.first.then((_) {
        _isPlaying = false;
      });
    } catch (e) {
      debugPrint('Play audio error: $e');
      _isPlaying = false;
    }
  }

  Future<void> playUrl(String url) async {
    try {
      _isPlaying = true;
      await _player.play(UrlSource(url));
      _player.onPlayerComplete.first.then((_) {
        _isPlaying = false;
      });
    } catch (e) {
      debugPrint('Play URL error: $e');
      _isPlaying = false;
    }
  }

  Future<void> stopPlayback() async {
    _isPlaying = false;
    await _player.stop();
  }

  void resetVAD() {
    _speechStartTime = null;
    _lastSoundTime = null;
  }

  void dispose() {
    _amplitudeSubscription?.cancel();
    _audioLevelController.close();
    _recorder.dispose();
    _player.dispose();
  }
}
