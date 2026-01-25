import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showContent = false;

  late final AnimationController _bgController;
  late final AnimationController _floatController;

  final List<OnboardingScene> _scenes = [
    OnboardingScene(
      title: "O'zbek tilidagi birinchi AI hamroh",
      subtitle:
          "Sizning tilingizda, sizning madaniyatingizda. Salom AI bilan muloqot qiling va kundalik vazifalaringizni osonlashtiring.",
      tag: "Salom AI",
      accent: AppTheme.accentPrimary,
    ),
    OnboardingScene(
      title: "Ovozli suhbat, xuddi do'stingizdek",
      subtitle:
          "Yozish shart emas. Shunchaki gapiring va tabiiy ovozda javob oling. Haqiqiy suhbatdosh kabi.",
      tag: "Ovozli Rejim",
      accent: AppTheme.accentSecondary,
    ),
    OnboardingScene(
      title: "Cheksiz imkoniyatlar olami",
      subtitle:
          "O'qish, ish, ijod va shaxsiy rivojlanish. Salom AI sizga har qadamda yordam berishga tayyor.",
      tag: "Premium",
      accent: AppTheme.accentTertiary,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
    _floatController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < _scenes.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scenes[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // 1. Dynamic Background
          _buildBackground(),

          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                AnimatedOpacity(
                  opacity: _showContent ? 1.0 : 0.0,
                  duration: 800.ms,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/app_icon_transparent.png',
                          width: 28,
                          height: 28,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Salom AI",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            "O'tkazib yuborish",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Hero Section
                Expanded(
                  flex: 3,
                  child: _buildHeroSection(),
                ),

                const Spacer(),

                // Bottom Card
                AnimatedSlide(
                  offset: _showContent ? Offset.zero : const Offset(0, 1),
                  duration: 800.ms,
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _showContent ? 1.0 : 0.0,
                    duration: 800.ms,
                    child: _buildBottomCard(scene),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: const Color(0xFF020617))),
        AnimatedBuilder(
          animation: _bgController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _bgController.value * 2 * 3.14159,
              child: Stack(
                children: [
                  Positioned(
                    top: -100,
                    left: -100,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentPrimary.withOpacity(0.3),
                      ),
                    ).animate().blurXY(end: 40),
                  ),
                  Positioned(
                    bottom: -100,
                    right: -100,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentSecondary.withOpacity(0.3),
                      ),
                    ).animate().blurXY(end: 40),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatController.value * 20 - 10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentPrimary.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate().blurXY(end: 20),

              // Character
              Image.asset(
                'assets/images/main_character_full_body.png',
                fit: BoxFit.contain,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomCard(OnboardingScene scene) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scene.tag.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scene.accent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: 400.ms,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  scene.title,
                  key: ValueKey('title_${_currentIndex}'),
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: 400.ms,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Text(
                  scene.subtitle,
                  key: ValueKey('sub_${_currentIndex}'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Indicators
                  Row(
                    children: List.generate(_scenes.length, (index) {
                      final isActive = index == _currentIndex;
                      return AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.only(right: 8),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Button
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.accentGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentPrimary.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScene {
  final String title;
  final String subtitle;
  final String tag;
  final Color accent;

  OnboardingScene({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.accent,
  });
}
