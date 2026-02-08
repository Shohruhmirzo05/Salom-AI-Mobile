import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/services/realtime_websocket_manager.dart';
import 'package:salom_ai/features/voice/realtime_voice_view_model.dart';
import 'package:salom_ai/features/voice/widgets/realtime_visualizer.dart';
import 'package:salom_ai/features/voice/voice_config_view.dart';
import 'package:salom_ai/core/constants/localization.dart';
import 'package:salom_ai/core/services/haptic_manager.dart';
import 'package:google_fonts/google_fonts.dart';

class RealtimeVoiceView extends ConsumerStatefulWidget {
  const RealtimeVoiceView({super.key});

  @override
  ConsumerState<RealtimeVoiceView> createState() => _RealtimeVoiceViewState();
}

class _RealtimeVoiceViewState extends ConsumerState<RealtimeVoiceView> {
  String _language = 'uz';
  String _voice = 'default';
  String _role = 'assistant';

  @override
  void initState() {
    super.initState();
    _startVoice();
  }

  void _startVoice() {
    Future.microtask(() {
      ref.read(realtimeVoiceProvider.notifier).start(
            language: _language,
            voice: _voice,
            role: _role,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(realtimeVoiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgMain,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        ref.read(realtimeVoiceProvider.notifier).stop();
                        Navigator.of(context).pop();
                      },
                    ),
                    const Spacer(),
                    Text(
                      ref.tr('voice_chat'),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white54),
                      onPressed: () async {
                        final config = await showVoiceConfigSheet(
                          context,
                          language: _language,
                          voice: _voice,
                          role: _role,
                        );
                        if (config != null) {
                          setState(() {
                            _language = config['language'] ?? _language;
                            _voice = config['voice'] ?? _voice;
                            _role = config['role'] ?? _role;
                          });
                          await ref.read(realtimeVoiceProvider.notifier).stop();
                          _startVoice();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Visualizer
              RealtimeVisualizer(
                audioLevel: state.audioLevel,
                isConnected: state.connectionState == RealtimeConnectionState.connected,
              ),

              const SizedBox(height: 32),

              // Status text
              Text(
                state.statusText ?? ref.tr('voice_connecting'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 16),

              // Transcription
              if (state.transcription != null && state.transcription!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.transcription!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 18, color: Colors.white),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // AI Response
              if (state.aiResponse != null && state.aiResponse!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: Text(
                    state.aiResponse!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppTheme.accentSecondary,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Error
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                  child: Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.danger),
                  ),
                ),

              const Spacer(),

              // Controls
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mute button
                    _ControlButton(
                      icon: state.isMuted ? Icons.mic_off : Icons.mic,
                      color: state.isMuted ? AppTheme.danger : Colors.white.withOpacity(0.15),
                      onTap: () {
                        HapticManager.medium();
                        ref.read(realtimeVoiceProvider.notifier).toggleMute();
                      },
                    ),
                    const SizedBox(width: 32),
                    // Hang up button
                    _ControlButton(
                      icon: Icons.call_end,
                      color: AppTheme.danger,
                      size: 72,
                      onTap: () {
                        HapticManager.heavy();
                        ref.read(realtimeVoiceProvider.notifier).stop();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 32),
                    // Interrupt button
                    _ControlButton(
                      icon: Icons.stop,
                      color: Colors.white.withOpacity(0.15),
                      onTap: () {
                        HapticManager.medium();
                        ref.read(realtimeVoiceProvider.notifier).interrupt();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.4),
      ),
    );
  }
}
