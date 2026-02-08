import 'dart:math';
import 'package:flutter/material.dart';
import 'package:salom_ai/core/theme/app_theme.dart';

class RealtimeVisualizer extends StatefulWidget {
  final double audioLevel;
  final bool isConnected;

  const RealtimeVisualizer({
    super.key,
    required this.audioLevel,
    required this.isConnected,
  });

  @override
  State<RealtimeVisualizer> createState() => _RealtimeVisualizerState();
}

class _RealtimeVisualizerState extends State<RealtimeVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _VisualizerPainter(
              audioLevel: widget.audioLevel,
              animationValue: _controller.value,
              isConnected: widget.isConnected,
            ),
          );
        },
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final double audioLevel;
  final double animationValue;
  final bool isConnected;

  _VisualizerPainter({
    required this.audioLevel,
    required this.animationValue,
    required this.isConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.3;

    // Outer glow
    final glowPaint = Paint()
      ..color = AppTheme.accentSecondary.withOpacity(0.1 + audioLevel * 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, baseRadius + 30 + audioLevel * 20, glowPaint);

    // Animated rings
    for (int i = 0; i < 3; i++) {
      final offset = i * 0.33;
      final phase = (animationValue + offset) % 1.0;
      final ringRadius = baseRadius + (audioLevel * 30 + 10) * phase;
      final opacity = (1.0 - phase) * (isConnected ? 0.3 : 0.1);

      final ringPaint = Paint()
        ..color = AppTheme.accentPrimary.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // Main circle
    final mainGradient = RadialGradient(
      colors: [
        isConnected
            ? AppTheme.accentPrimary.withOpacity(0.6 + audioLevel * 0.4)
            : Colors.white.withOpacity(0.1),
        isConnected
            ? AppTheme.accentSecondary.withOpacity(0.3)
            : Colors.white.withOpacity(0.05),
      ],
    );

    final mainPaint = Paint()
      ..shader = mainGradient.createShader(
        Rect.fromCircle(center: center, radius: baseRadius + audioLevel * 15),
      );
    canvas.drawCircle(center, baseRadius + audioLevel * 15, mainPaint);

    // Inner bright circle
    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(isConnected ? 0.15 : 0.05);
    canvas.drawCircle(center, baseRadius * 0.6, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.isConnected != isConnected;
  }
}
