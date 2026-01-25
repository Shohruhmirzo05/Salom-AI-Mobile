import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:salom_ai/features/auth/auth_service.dart';
import 'package:salom_ai/features/auth/login_screen.dart';
import 'package:salom_ai/features/home/home_screen.dart';
import 'package:salom_ai/features/chat/chat_screen.dart';
import 'package:salom_ai/features/onboarding/onboarding_screen.dart';
import 'package:salom_ai/features/onboarding/splash_screen.dart';
import 'package:salom_ai/features/settings/settings_screen.dart';
import 'package:salom_ai/features/settings/subscription_view.dart';
import 'package:salom_ai/features/settings/feedback_view.dart';

// Provider for SharedPreferences (To be overridden in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authService,
    redirect: (context, state) {
      final isLoggedIn = authService.isAuthenticated;
      final hasCompletedOnboarding =
          prefs.getBool('hasCompletedOnboarding') ?? false;

      final isSplash = state.uri.path == '/splash';
      final isOnboarding = state.uri.path == '/onboarding';
      final isLogin = state.uri.path == '/login';

      // Always allow splash
      if (isSplash) return null;

      // Logic for Onboarding
      if (!hasCompletedOnboarding) {
         if (isOnboarding) return null;
         return '/onboarding';
      }

      // Logic for Auth
      if (!isLoggedIn) {
        if (isLogin) return null;
        return '/login';
      }

      // If logged in and trying to access login/onboarding, go to home
      if (isLoggedIn && (isLogin || isOnboarding)) return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(key: ValueKey('splash')),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChatScreen(
              conversationId: 0,
              onMenuTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '0');
              return ChatScreen(
                conversationId: id ?? 0,
                onMenuTap: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'subscription',
            builder: (context, state) => const SubscriptionView(),
          ),
          GoRoute(
            path: 'feedback',
            builder: (context, state) => const FeedbackView(),
          ),
        ],
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
