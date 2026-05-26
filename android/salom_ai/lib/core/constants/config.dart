class Config {
  // Base URLs
  static const String apiBaseUrl = 'https://api.salom-ai.uz';
  static const String supabaseUrl = 'https://cfvlfcgvggbgcjbunsjk.supabase.co';

  // Supabase anonymous key (public — safe to embed).
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmdmxmY2d2Z2diZ2NqYnVuc2prIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2NTc2MzMsImV4cCI6MjA3OTIzMzYzM30.1j-9j6vhZJWc_QdUsMufatthhx-uy0TWE9EhZxAVLvI';

  // Google OAuth — Web client ID used as serverClientId (returns ID token for /auth/oauth/verify).
  static const String googleClientId =
      '347718573096-iqp1uj4ido18qgfguqrlh00vil3qafcc.apps.googleusercontent.com';

  // OneSignal — same App ID as production iOS app.
  // If a separate Android app is created in OneSignal, override via --dart-define=ONESIGNAL_APP_ID=...
  static const String onesignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '4bf70eb4-54f5-4479-8ef4-70e262dc6d2b',
  );

  // ============================================================
  // Google Cloud Console — Android OAuth client requirements:
  //   Package name: com.feratech.salomai
  //   SHA-1 (debug):   98:AE:C8:A1:F0:09:7E:AD:9B:B1:E6:09:AD:35:4A:2E:6C:82:C6:0B
  //   SHA-1 (release): generate via `keytool -list -v -keystore your-upload.keystore`
  // ============================================================
}
