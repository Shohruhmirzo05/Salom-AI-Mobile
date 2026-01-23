import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/features/auth/auth_service.dart';
import 'package:salom_ai/features/auth/login_screen.dart';
import 'package:salom_ai/features/home/home_screen.dart';
import 'package:salom_ai/features/chat/chat_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authService.onAuthStateChange),
    redirect: (context, state) {
      final isLoggedIn = authService.currentSession != null;
      final isLoggingIn = state.uri.path == '/login';
      
      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'chat/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '0');
              return ChatScreen(conversationId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
});

// Helper for generic stream listening
import 'dart:async';
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
