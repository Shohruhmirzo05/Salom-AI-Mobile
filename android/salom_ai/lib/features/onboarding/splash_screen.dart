import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/features/auth/auth_service.dart';
import 'package:salom_ai/features/settings/paywall_sheet.dart';

/// Tracks whether the paywall has been shown this session.
final _paywallShownProvider = StateProvider<bool>((ref) => false);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // Pre-load subscription data while splash is animating
    final auth = ref.read(authServiceProvider);
    if (auth.isAuthenticated) {
      try {
        await ref.read(subscriptionManagerProvider.notifier).loadAll();
      } catch (_) {}
    }

    // Wait for splash animation
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Navigate to main content
    context.go('/');

    // Show paywall if user is authenticated, not pro, and hasn't seen it this session
    if (auth.isAuthenticated) {
      final subState = ref.read(subscriptionManagerProvider);
      final alreadyShown = ref.read(_paywallShownProvider);
      if (!subState.isPro && !alreadyShown) {
        ref.read(_paywallShownProvider.notifier).state = true;
        // Small delay to let the home screen build first
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          showPaywallSheet(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),

          // Glow Effect
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260 * 2,
                height: 260 * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accentSecondary.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                      duration: 1400.ms,
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.2, 1.2),
                      curve: Curves.easeInOut)
                  .fadeIn(duration: 1400.ms),
            ),
          ),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/app_icon_transparent.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                )
                    .animate()
                    .scale(
                        duration: 800.ms,
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.05, 1.05),
                        curve: Curves.elasticOut)
                    .fadeIn(duration: 800.ms),
                const SizedBox(height: 16),
                Text(
                  "Salom AI",
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 600.ms)
                    .moveY(begin: 20, end: 0),
                Text(
                  "O'zbek ai yordamchisi",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .moveY(begin: 20, end: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
