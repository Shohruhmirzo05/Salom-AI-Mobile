import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // Base URLs
  static const String apiBaseUrl = 'https://api.salom-ai.uz';
  static const String supabaseUrl = 'https://cfvlfcgvggbgcjbunsjk.supabase.co';
  
  // Keys (Ideally these should be in .env, but hardcoding for now to match iOS behavior if .env fails)
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJa9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmdmxmY2d2Z2diZ2NqYnVuc2prIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM2NTc2MzMsImV4cCI6MjA3OTIzMzYzM30.1j-9j6vhZJWc_QdUsMufatthhx-uy0TWE9EhZxAVLvI';

  // OAuth Setup (Google)
  static const String googleClientId = '347718573096-ki8ir8dmk06osats71t7qp3q2fcks8qm.apps.googleusercontent.com';
  // Note: For Android, we might need a separate Android Client ID from Google Cloud Console
  // The iOS Client ID usually doesn't work directly on Android for native sign-in.
  // Using the Web Client ID is often the way to go for cross-platform Supabase Auth.
}
