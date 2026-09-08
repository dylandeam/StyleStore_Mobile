import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta Oficial StyleStore: Beige & Navy
  static const Color bgPrimary = Color(0xFFEEE7D8);      // Fondo cálido beige
  static const Color bgSecondary = Color(0xFFE2DAC8);    // Fondo secundario
  static const Color bgCard = Color(0xFFFBF8F1);         // Tarjetas crema claro
  static const Color accentIndigo = Color(0xFF14263D);   // Navy principal
  static const Color accentPurple = Color(0xFF274C77);   // Navy medio / Links
  static const Color accentPink = Color(0xFF1D3552);     // Navy oscuro
  static const Color successGreen = Color(0xFF16A34A);   // Verde éxito
  static const Color dangerRed = Color(0xFFDC2626);      // Rojo peligro
  static const Color textPrimary = Color(0xFF14263D);    // Texto principal
  static const Color textSecondary = Color(0xFF475569);  // Texto secundario
  static const Color textMuted = Color(0xFF64748B);      // Texto atenuado
  static const Color borderGlass = Color(0xFFD9D0BF);    // Borde beige sutil

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: accentIndigo,
      cardColor: bgCard,
      colorScheme: const ColorScheme.light(
        primary: accentIndigo,
        secondary: accentPurple,
        surface: bgCard,
        error: dangerRed,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgCard,
        foregroundColor: textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: accentIndigo),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
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
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // Alias para retrocompatibilidad
  static ThemeData get darkTheme => lightTheme;
}

