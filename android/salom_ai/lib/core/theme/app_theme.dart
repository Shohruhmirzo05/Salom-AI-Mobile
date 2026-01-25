import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors (Matching iOS SalomTheme)
  static const Color bgMain = Color(0xFF050617);
  static const Color bgSecondary = Color(0xFF080A1F);
  static const Color accentPrimary = Color(0xFF7C3AED); // deep purple
  static const Color accentSecondary = Color(0xFF1ED6FF); // cyan-blue glow
  static const Color accentTertiary = Color(0xFF4B87FF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB8FFFFFF); // white with 0.72 opacity
  static const Color danger = Color(0xFFF97373);
  static const Color card = bgSecondary;
  static const Color background = bgMain;
  static const Color primary = accentPrimary;
  static const Color error = danger;

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [
      Color(0xFF06071C),
      Color(0xFF0B0E26),
      Color(0xFF0A0B22),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [
      Color(0xFF1ED6FF),
      Color(0xFFA855F7),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgMain,
      primaryColor: accentPrimary,
      colorScheme: const ColorScheme.dark(
        primary: accentPrimary,
        secondary: accentSecondary,
        surface: bgSecondary,
        background: bgMain,
        error: danger,
        onPrimary: textPrimary,
        onSecondary: bgMain, // Text on accent should be dark usually, or white depending on contrast. keeping logic sane.
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSecondary, // Using secondary bg for inputs
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentPrimary, width: 2),
        ),
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static BoxDecoration get glassCardDecoration {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    );
  }
}
