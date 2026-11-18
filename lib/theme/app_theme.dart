import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual identity: police navy with a brass-gold badge accent, flat cards,
/// small corner radii and a single plain font (Inter).
class AppTheme {
  // Brand
  static const Color primary = Color(0xFF1F3A5F); // Police navy
  static const Color primaryLight = Color(0xFFD6DFEA); // Light steel
  static const Color primaryDark = Color(0xFF14283F); // Deep navy
  static const Color secondary = Color(0xFF2E5C8A); // Uniform blue
  static const Color secondaryLight = Color(0xFFDCE6F1);
  static const Color accent = Color(0xFFB8860B); // Badge gold
  static const Color accentLight = Color(0xFFF3E9CC);
  static const Color warning = Color(0xFFB7791F);
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF2F6B3F);

  // Neutrals
  static const Color background = Color(0xFFF2F4F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE9EDF2);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFD5DAE1);

  // Text
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textMuted = Color(0xFF718096);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Gradients (kept subtle so they read as solid navy)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F3A5F), Color(0xFF2E5C8A)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE9EDF2), Color(0xFFF2F4F7)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF7F9FB)],
  );

  static const LinearGradient recordingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB3261E), Color(0xFF8E1B14)],
  );

  static ThemeData get lightTheme {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: textOnPrimary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      dividerColor: divider,
      textTheme: base.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: divider),
        ),
        color: cardBg,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
    );
  }
}
