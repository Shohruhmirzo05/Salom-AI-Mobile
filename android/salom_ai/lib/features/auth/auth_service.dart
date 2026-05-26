import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:salom_ai/core/api/api_client.dart';
import 'package:salom_ai/core/api/token_store.dart';
import 'package:salom_ai/core/api/api_models.dart';
import 'package:salom_ai/core/constants/config.dart';
import 'package:salom_ai/core/services/push_notification_service.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_lib;

// Make AuthService a ChangeNotifier to notify Router
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ApiClient _apiClient;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  User? get currentUser => _supabase.auth.currentUser; // Supabase user
  OAuthUser? _backendUser; // Backend user
  OAuthUser? get backendUser => _backendUser;

  AuthService(this._apiClient) {
    _init();
  }

  Future<void> _init() async {
    // Check local tokens first
    final token = await TokenStore.shared.getAccessToken();
    if (token != null) {
      _isAuthenticated = true;
      notifyListeners();
      // Fetch user info in background
      _fetchBackendUser();
    }

    // Listen to Supabase Auth State (for OAuth flow completion)
    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        // We have a Supabase session. Check if we need to exchange token.
        // For OAuth, Supabase provides providerToken (ID Token).
        final idToken = session.providerToken;
        
        if (idToken != null) {
          try {
             print("🔵 [Auth] Exchanging ID Token with Backend...");
             final tokens = await _apiClient.oauthVerify(idToken);
             print("✅ [Auth] Backend verified. Saving tokens.");
             await TokenStore.shared.saveTokens(tokens.accessToken, tokens.refreshToken);
             
             _isAuthenticated = true;
             notifyListeners();
             await _fetchBackendUser();
          } catch (e) {
             print("❌ [Auth] Exchange failed: $e");
             // Force logout if backend rejects it
             await signOut(); 
          }
        } 
      } else if (event == AuthChangeEvent.signedOut) {
         if (_isAuthenticated) {
           await signOut();
         }
      }
    });
  }

  /// Call after externally writing tokens to TokenStore (e.g. after phone-OTP verify)
  /// so the router and rest of the app pick up the new authenticated state.
  Future<void> reloadFromTokens() async {
    final token = await TokenStore.shared.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _isAuthenticated = true;
      notifyListeners();
      await _fetchBackendUser();
    }
  }

  Future<void> _fetchBackendUser() async {
    try {
      _backendUser = await _apiClient.getMe();
      notifyListeners();
      // Bind OneSignal subscription to backend user id so push targeting works.
      final uid = _backendUser?.id;
      if (uid != null) {
        await PushNotificationService.instance.setExternalUserId(uid.toString());
        // Best-effort: ask for notification permission once after first login.
        unawaited(PushNotificationService.instance.requestPermission());
      }
    } catch (e) {
      print("⚠️ Failed to fetch user profile: $e");
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      // Step 1: Get Google ID token using native sign-in
      final googleSignIn = google_lib.GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: Config.googleClientId, // Web Client ID
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Google Sign In cancelled by user.';
      }
      
      final googleAuth = await googleUser.authentication;
      final googleIdToken = googleAuth.idToken;
      
      if (googleIdToken == null) {
        throw 'No ID Token found.';
      }

      print("✅ [Google] Native Sign In successful.");
      print("🔵 [Auth] Exchanging Google ID Token with Supabase...");
     
      // Step 2: Exchange Google ID token with Supabase (matching iOS flow)
      // This calls: POST https://cfvlfcgvggbgcjbunsjk.supabase.co/auth/v1/token?grant_type=id_token
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleIdToken,
      );
      
      if (response.session == null) {
        throw 'Failed to create Supabase session';
      }
      
      final supabaseAccessToken = response.session!.accessToken;
      print("✅ [Auth] Supabase session created.");
      print("🔵 [Auth] Sending Supabase token to backend...");
      
      // Step 3: Send Supabase access token to backend (matching iOS)
      final tokens = await _apiClient.oauthVerify(supabaseAccessToken);
      
      print("✅ [Auth] Backend verified. Saving tokens.");
      await TokenStore.shared.saveTokens(tokens.accessToken, tokens.refreshToken);
      
      _isAuthenticated = true;
      notifyListeners();
      await _fetchBackendUser();
      
    } catch (e) {
      print("❌ [Google Sign In Error]: $e");
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    throw UnimplementedError("Apple Sign In not implemented on Android");
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    try {
      await google_lib.GoogleSignIn().signOut();
    } catch(_) {}

    await PushNotificationService.instance.clearExternalUserId();
    await TokenStore.shared.clear();
    _isAuthenticated = false;
    _backendUser = null;
    notifyListeners();
  }
}
