import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/tenant_portal.dart';

class AppTheme {
  // Paleta Oficial StyleStore: Beige & Navy
  static const Color bgPrimary = Color(0xFFEEE7D8); // Fondo cálido beige
  static const Color bgSecondary = Color(0xFFE2DAC8); // Fondo secundario
  static const Color bgCard = Color(0xFFFBF8F1); // Tarjetas crema claro
  static const Color accentIndigo = Color(0xFF14263D); // Navy principal
  static const Color accentPurple = Color(0xFF274C77); // Navy medio / Links
  static const Color accentPink = Color(0xFF1D3552); // Navy oscuro
  static const Color accentGold = Color(0xFFC8A97E); // Dorado luxury
  static const Color successGreen = Color(0xFF16A34A); // Verde éxito
  static const Color dangerRed = Color(0xFFDC2626); // Rojo peligro
  static const Color warningOrange =
      Color(0xFFD97706); // Estado offline/pendiente
  static const Color textPrimary = Color(0xFF14263D); // Texto principal
  static const Color textSecondary = Color(0xFF475569); // Texto secundario
  static const Color textMuted = Color(0xFF64748B); // Texto atenuado
  static const Color borderGlass = Color(0xFFD9D0BF); // Borde beige sutil

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

  static double contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    final light =
        firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
    final dark =
        firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
    return (light + 0.05) / (dark + 0.05);
  }

  static Color readableOn(Color background, {Color? preferred}) {
    final requested = preferred ?? textPrimary;
    if (contrastRatio(background, requested) >= 4.5) return requested;
    final candidates = <Color>[Colors.white, Colors.black, textPrimary];
    candidates.sort((a, b) =>
        contrastRatio(background, b).compareTo(contrastRatio(background, a)));
    return candidates.first;
  }

  static ThemeData forTenant(TenantPortal? portal) {
    if (portal == null) return lightTheme;
    final primary = portal.primaryColor;
    final secondary = portal.accentColor;
    final surface = portal.secondaryColor;
    final background = portal.backgroundColor;
    final onBackground = readableOn(background, preferred: portal.textColor);
    final onSurface = readableOn(surface, preferred: portal.textColor);
    final onPrimary = readableOn(primary, preferred: portal.contrastTextColor);
    final onSecondary =
        readableOn(secondary, preferred: portal.contrastTextColor);
    const controlSurface = Colors.white;
    final onControl = readableOn(controlSurface, preferred: portal.textColor);
    final mutedOnControl = onControl.withValues(alpha: 0.72);
    return lightTheme.copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      cardColor: surface,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: dangerRed,
        onPrimary: onPrimary,
        onSecondary: onSecondary,
        onSurface: onSurface,
        onError: readableOn(dangerRed, preferred: Colors.white),
      ),
      textTheme:
          GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme)
              .apply(bodyColor: onBackground, displayColor: onBackground),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(color: surface),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(color: onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color:
                  states.contains(WidgetState.selected) ? onPrimary : onSurface,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? onSurface
                  : onSurface.withValues(alpha: 0.82),
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: controlSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: TextStyle(color: mutedOnControl),
        floatingLabelStyle: TextStyle(color: onControl),
        hintStyle: TextStyle(color: mutedOnControl, fontSize: 14),
        prefixIconColor: onControl,
        suffixIconColor: onControl,
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
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.22),
        selectionHandleColor: primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
