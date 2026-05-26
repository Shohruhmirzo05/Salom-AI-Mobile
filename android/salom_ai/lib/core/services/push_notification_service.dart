import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:salom_ai/core/constants/config.dart';

/// Wraps OneSignal so the rest of the app doesn't depend on the SDK directly.
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      OneSignal.Debug.setLogLevel(
        kDebugMode ? OSLogLevel.warn : OSLogLevel.error,
      );
      OneSignal.initialize(Config.onesignalAppId);
      // Don't auto-prompt — we ask at a more natural moment (post-login).
    } catch (e) {
      debugPrint('⚠️ [Push] OneSignal init failed: $e');
    }
  }

  /// Request notification permission. Returns true if granted.
  Future<bool> requestPermission() async {
    try {
      final granted = await OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 [Push] Permission granted=$granted');
      return granted;
    } catch (e) {
      debugPrint('⚠️ [Push] requestPermission failed: $e');
      return false;
    }
  }

  /// Bind the OneSignal subscription to our user id so the backend can target this user.
  Future<void> setExternalUserId(String userId) async {
    try {
      await OneSignal.login(userId);
      debugPrint('🔔 [Push] External user id set: $userId');
    } catch (e) {
      debugPrint('⚠️ [Push] setExternalUserId failed: $e');
    }
  }

  Future<void> clearExternalUserId() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('⚠️ [Push] clearExternalUserId failed: $e');
    }
  }

  /// Optional tags (e.g. preferred language) used by OneSignal segmentation.
  Future<void> setTags(Map<String, String> tags) async {
    try {
      await OneSignal.User.addTags(tags);
    } catch (e) {
      debugPrint('⚠️ [Push] setTags failed: $e');
    }
  }
}
