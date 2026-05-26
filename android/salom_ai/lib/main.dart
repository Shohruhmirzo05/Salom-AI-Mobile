import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:salom_ai/core/constants/config.dart';
import 'package:salom_ai/core/services/push_notification_service.dart';
import 'package:salom_ai/core/services/subscription_manager.dart';
import 'package:salom_ai/core/theme/app_theme.dart';
import 'package:salom_ai/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase
  await Supabase.initialize(
    url: Config.supabaseUrl,
    anonKey: Config.supabaseAnonKey,
  );

  // OneSignal — fire and forget; permission prompt happens after login.
  unawaited(PushNotificationService.instance.init());

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const SalomAIApp(),
    ),
  );
}

class SalomAIApp extends ConsumerStatefulWidget {
  const SalomAIApp({super.key});

  @override
  ConsumerState<SalomAIApp> createState() => _SalomAIAppState();
}

class _SalomAIAppState extends ConsumerState<SalomAIApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned to the app (e.g. after paying in Click in external browser).
      // Refresh subscription so paid one-time / auto-renew status reflects immediately.
      ref.read(subscriptionManagerProvider.notifier).checkSubscriptionStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Salom AI',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
