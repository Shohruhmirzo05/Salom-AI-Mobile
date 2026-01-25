// import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // Base URLs
  static const String apiBaseUrl = 'https://api.salom-ai.uz';
  static const String supabaseUrl = 'https://cfvlfcgvggbgcjbunsjk.supabase.co';
  
  // Keys (Ideally these should be in .env, but hardcoding for now to match iOS behavior if .env fails)
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmdmxmY2d2Z2diZ2NqYnVuc2prIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2NTc2MzMsImV4cCI6MjA3OTIzMzYzM30.1j-9j6vhZJWc_QdUsMufatthhx-uy0TWE9EhZxAVLvI';

  // OAuth Setup (Google)
  // Web Client ID for serverClientId (enables ID token for backend verification)
  static const String googleClientId = '347718573096-iqp1uj4ido18qgfguqrlh00vil3qafcc.apps.googleusercontent.com';
  
  // Note: You also need an Android OAuth client in Google Cloud Console with:
  // Package name: com.example.salom_ai
  // SHA-1: 98:AE:C8:A1:F0:09:7E:AD:9B:B1:E6:09:AD:35:4A:2E:6C:82:C6:0B
}
