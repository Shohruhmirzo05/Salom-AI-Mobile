import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salom_ai/core/constants/config.dart';

final authServiceProvider = Provider((ref) => AuthService());

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;
  
  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  Future<void> initialize() async {
    // Supabase.initialize() is called in main.dart
  }

  // Sign In with Google (ID Token flow typically handled on client in Flutter)
  // Or using Native Sign In
  Future<void> signInWithGoogle() async {
    // This typically requires `google_sign_in` package to get ID Token,
    // then pass to Supabase.
    // For now, implementing the specific method to exchange ID token if needed or standard OAuth.
    
    // Web-based OAuth (works on Android too)
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://callback',
    );
  }

  Future<void> signInWithApple() async {
    await _supabase.auth.signInWithApple();
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
  
  // Custom API helper to exchange tokens if doing custom flow (like iOS manager did)
  // But typically supabase_flutter handles this.
}
