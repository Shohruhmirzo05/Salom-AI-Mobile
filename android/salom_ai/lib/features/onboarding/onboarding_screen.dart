import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salom_ai/core/theme/app_theme.dart';

enum SceneKind { welcome, chat, voice, image, files, planning, ready }

class OnboardingScene {
  final SceneKind kind;
  final String title;
  final String subtitle;
  final String tag;
  final Color accent;
  final Color accent2;
  const OnboardingScene({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.accent,
    required this.accent2,
  });
}

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

  final List<OnboardingScene> _scenes = const [
    OnboardingScene(
      kind: SceneKind.welcome,
      title: "O'zbek tilidagi birinchi AI hamroh",
      subtitle:
          "Sizning tilingizda, sizning madaniyatingizda. Salom AI bilan kundalik vazifalarni osonlashtiring.",
      tag: "Xush kelibsiz",
      accent: AppTheme.accentPrimary,
      accent2: AppTheme.accentSecondary,
    ),
    OnboardingScene(
      kind: SceneKind.chat,
      title: "Aqlli suhbatdosh",
      subtitle:
          "Yozing, savol bering, fikrlashing. AI sizning matnlaringizga aniq va tabiiy javob beradi — oʻzbek, rus va ingliz tillarida.",
      tag: "Chat",
      accent: AppTheme.accentSecondary,
      accent2: AppTheme.accentPrimary,
    ),
    OnboardingScene(
      kind: SceneKind.voice,
      title: "Ovozli suhbat, real vaqtda",
      subtitle:
          "Mikrofonni bosing va gapiring. Salom AI sizni eshitadi, tushunadi va oʻz ovozi bilan javob beradi.",
      tag: "Ovozli rejim",
      accent: AppTheme.accentPrimary,
      accent2: AppTheme.accentTertiary,
    ),
    OnboardingScene(
      kind: SceneKind.image,
      title: "Tasavvuringizni chizamiz",
      subtitle:
          "Bir necha soʻz bilan istalgan rasm — afisha, dizayn, illyustratsiya — yarating. Bir necha soniyada tayyor.",
      tag: "Rasm yaratish",
      accent: AppTheme.accentTertiary,
      accent2: AppTheme.accentPrimary,
    ),
    OnboardingScene(
      kind: SceneKind.files,
      title: "Hujjat va rasmlarni tahlil qilish",
      subtitle:
          "PDF, rasm, kvitansiya, kontrakt — fayl yuboring, AI oʻqiydi, tarjima qiladi va xulosa beradi.",
      tag: "Fayl tahlili",
      accent: AppTheme.accentSecondary,
      accent2: AppTheme.accentTertiary,
    ),
    OnboardingScene(
      kind: SceneKind.planning,
      title: "Reja, hisob va muammolar yechimi",
      subtitle:
          "Matematika, dasturlash, kunlik reja, sayohat marshruti — eng kerakli vazifalarni yoʻlda hal qiling.",
      tag: "Reja va hisob",
      accent: AppTheme.accentPrimary,
      accent2: AppTheme.accentSecondary,
    ),
    OnboardingScene(
      kind: SceneKind.ready,
      title: "Boshlashga tayyormiz",
      subtitle:
          "Hamma narsa tayyor. Salom AI bilan birinchi suhbatingizni boshlang — yangi imkoniyatlar olamiga xush kelibsiz.",
      tag: "Tayyor",
      accent: AppTheme.accentTertiary,
      accent2: AppTheme.accentPrimary,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 400), () {
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
    HapticFeedback.lightImpact();
    if (_currentIndex < _scenes.length - 1) {
      setState(() => _currentIndex++);
    } else {
      HapticFeedback.heavyImpact();
      _completeOnboarding();
    }
  }

  void _prev() {
    if (_currentIndex == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex--);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scenes[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -250) _next();
          else if (v > 250) _prev();
        },
        child: Stack(
          children: [
            _buildBackground(scene),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const Spacer(),
                  Expanded(
                    flex: 3,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween(begin: 0.92, end: 1.0).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_currentIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Center(child: _buildHero(scene)),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
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
      ),
    );
  }

  Widget _buildBackground(OnboardingScene scene) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        return Stack(
          children: [
            Container(color: const Color(0xFF020617)),
            Positioned.fill(
              child: Transform.rotate(
                angle: _bgController.value * 2 * math.pi,
                child: Stack(
                  children: [
                    Positioned(
                      left: -100,
                      top: -200,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scene.accent.withOpacity(0.32),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -100,
                      bottom: -200,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scene.accent2.withOpacity(0.28),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.compose(
                outer: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                inner: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              ),
              child: Container(color: Colors.transparent),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar() {
    return AnimatedOpacity(
      opacity: _showContent ? 1.0 : 0.0,
      duration: 800.ms,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Image.asset('assets/images/app_icon_transparent.png',
                width: 28, height: 28),
            const SizedBox(width: 8),
            const Text(
              "Salom AI",
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                _completeOnboarding();
              },
              child: Text(
                "O'tkazib yuborish",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(OnboardingScene scene) {
    Widget hero;
    switch (scene.kind) {
      case SceneKind.welcome:
        hero = _WelcomeHero(floatController: _floatController);
        break;
      case SceneKind.chat:
        hero = _ChatHero(accent: scene.accent);
        break;
      case SceneKind.voice:
        hero = _VoiceHero(accent: scene.accent);
        break;
      case SceneKind.image:
        hero = _ImageHero(accent: scene.accent);
        break;
      case SceneKind.files:
        hero = _FilesHero(accent: scene.accent);
        break;
      case SceneKind.planning:
        hero = _PlanningHero(accent: scene.accent);
        break;
      case SceneKind.ready:
        hero = _ReadyHero(accent: scene.accent);
        break;
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [scene.accent.withOpacity(0.5), Colors.transparent],
            ),
          ),
        ),
        hero,
      ],
    );
  }

  Widget _buildBottomCard(OnboardingScene scene) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scene.tag.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scene.accent,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: 350.ms,
                child: Text(
                  scene.title,
                  key: ValueKey('title-$_currentIndex'),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: 350.ms,
                child: Text(
                  scene.subtitle,
                  key: ValueKey('sub-$_currentIndex'),
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Row(
                    children: List.generate(_scenes.length, (i) {
                      final active = i == _currentIndex;
                      return AnimatedContainer(
                        duration: 300.ms,
                        margin: const EdgeInsets.only(right: 8),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.accentPrimary,
                            AppTheme.accentSecondary
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scene.accent.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        _currentIndex == _scenes.length - 1
                            ? Icons.check
                            : Icons.arrow_forward,
                        color: Colors.white,
                        size: 28,
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

// =================== Per-scene heroes ===================

class _WelcomeHero extends StatelessWidget {
  final AnimationController floatController;
  const _WelcomeHero({required this.floatController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatController,
      builder: (context, _) {
        final offset = (floatController.value - 0.5) * 20;
        return Transform.translate(
          offset: Offset(0, offset),
          child: Image.asset(
            'assets/images/main_character_full_body.png',
            height: MediaQuery.of(context).size.height * 0.38,
          ),
        );
      },
    );
  }
}

class _ChatHero extends StatefulWidget {
  final Color accent;
  const _ChatHero({required this.accent});
  @override
  State<_ChatHero> createState() => _ChatHeroState();
}

class _ChatHeroState extends State<_ChatHero> {
  int _typingDot = 0;
  late final Stream<int> _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(milliseconds: 350), (i) => i % 3);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bubble("Direktorga rasmiy ariza yozib ber", isUser: true),
        const SizedBox(height: 14),
        _bubble("Albatta! Mana professional uslubdagi ariza...", isUser: false),
        const SizedBox(height: 14),
        StreamBuilder<int>(
          stream: _ticker,
          builder: (context, snap) {
            _typingDot = snap.data ?? 0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withOpacity(_typingDot == i ? 0.9 : 0.25),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _bubble(String text, {required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? widget.accent.withOpacity(0.85) : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _VoiceHero extends StatefulWidget {
  final Color accent;
  const _VoiceHero({required this.accent});
  @override
  State<_VoiceHero> createState() => _VoiceHeroState();
}

class _VoiceHeroState extends State<_VoiceHero> {
  final _rng = math.Random();
  List<double> _bars = List.filled(21, 0.4);
  late final Stream<int> _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(milliseconds: 120), (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: widget.accent.withOpacity(0.4), width: 2),
              ),
            ),
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [widget.accent, widget.accent.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.5), blurRadius: 30)],
              ),
              child: const Icon(Icons.mic, size: 50, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 28),
        StreamBuilder<int>(
          stream: _ticker,
          builder: (context, _) {
            _bars = _bars.map((_) => _rng.nextDouble() * 0.8 + 0.2).toList();
            return SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _bars
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            width: 4,
                            height: h * 50,
                            decoration: BoxDecoration(
                              color: widget.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ImageHero extends StatefulWidget {
  final Color accent;
  const _ImageHero({required this.accent});
  @override
  State<_ImageHero> createState() => _ImageHeroState();
}

class _ImageHeroState extends State<_ImageHero> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < 5; i++)
            Transform.translate(
              offset: Offset((i - 2) * 14, (i - 2).abs() * 6),
              child: Transform.rotate(
                angle: (i - 2) * 0.14,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [widget.accent.withOpacity(0.6), widget.accent.withOpacity(0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => Transform.rotate(
              angle: _ctrl.value * 2 * math.pi,
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 64),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilesHero extends StatefulWidget {
  final Color accent;
  const _FilesHero({required this.accent});
  @override
  State<_FilesHero> createState() => _FilesHeroState();
}

class _FilesHeroState extends State<_FilesHero> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final scanY = (_ctrl.value - 0.5) * 160;
        return Container(
          width: 220,
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 16))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line(130, 0.55),
                      const SizedBox(height: 10),
                      _line(170, 0.18),
                      const SizedBox(height: 10),
                      _line(140, 0.18),
                      const SizedBox(height: 10),
                      _line(160, 0.18),
                      const SizedBox(height: 10),
                      _line(120, 0.18),
                      const SizedBox(height: 10),
                      _line(150, 0.18),
                    ],
                  ),
                ),
                Positioned(
                  left: 0, right: 0,
                  top: 140 + scanY,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, widget.accent.withOpacity(0.7), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(double w, double o) => Container(
        width: w,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(o),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

class _PlanningHero extends StatelessWidget {
  final Color accent;
  const _PlanningHero({required this.accent});
  @override
  Widget build(BuildContext context) {
    final items = [
      ('2x + 5 = 13 → x = 4', Icons.functions, true),
      ('Bugun ish rejasi', Icons.calendar_today, true),
      ('Sayohat marshruti', Icons.map_outlined, false),
      ('Email javobi', Icons.email_outlined, false),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        final (text, icon, done) = item;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? accent : Colors.white.withOpacity(0.1),
                  ),
                  child: Icon(done ? Icons.check : icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 14),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReadyHero extends StatefulWidget {
  final Color accent;
  const _ReadyHero({required this.accent});
  @override
  State<_ReadyHero> createState() => _ReadyHeroState();
}

class _ReadyHeroState extends State<_ReadyHero> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final scale = 0.7 + _ctrl.value * 0.35;
        return SizedBox(
          width: 280, height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 140 + i * 60.0,
                    height: 140 + i * 60.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accent.withOpacity(0.4 - i * 0.12),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [widget.accent, widget.accent.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.55), blurRadius: 30)],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 64),
              ),
            ],
          ),
        );
      },
    );
  }
}
