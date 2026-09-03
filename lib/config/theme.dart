import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color bgPrimary = Color(0xFF0A0D14);
  static const Color bgSecondary = Color(0xFF101524);
  static const Color bgCard = Color(0xFF161C2E);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color successGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderGlass = Color(0x1AFFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: accentIndigo,
      colorScheme: const ColorScheme.dark(
        primary: accentIndigo,
        secondary: accentPurple,
        surface: bgCard,
        error: dangerRed,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x990F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGlass),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderGlass),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentIndigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerRed),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentIndigo,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
