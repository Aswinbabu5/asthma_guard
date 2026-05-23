// lib/config/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Color Palette ─────────────────────────────────────────────────────
class AppColors {
  // Backgrounds
  static const bg0 = Color(0xFF03080F);
  static const bg1 = Color(0xFF070D18);
  static const bg2 = Color(0xFF0C1220);
  static const surface = Color(0xFF111827);
  static const surfaceElevated = Color(0xFF161E2E);
  static const surfaceHighest = Color(0xFF1C2538);

  // Primary — electric indigo-blue
  static const primary = Color(0xFF4F80FF);
  static const primaryLight = Color(0xFF7BA3FF);
  static const primaryDark = Color(0xFF2B58D6);
  static const primaryGlow = Color(0x334F80FF);

  // Accent
  static const accent = Color(0xFF00E5C8);
  static const accentGlow = Color(0x2200E5C8);

  // Semantic
  static const success = Color(0xFF00D68F);
  static const warning = Color(0xFFFFB347);
  static const danger  = Color(0xFFFF4560);
  static const purple  = Color(0xFFA855F7);

  // Text
  static const textPrimary   = Color(0xFFF0F4FF);
  static const textSecondary = Color(0xFF8B97B8);
  static const textMuted     = Color(0xFF4A5568);

  // Borders
  static const border        = Color(0x1A4F80FF);
  static const borderMid     = Color(0x334F80FF);
  static const borderStrong  = Color(0x664F80FF);
}

// ── AQI utilities ─────────────────────────────────────────────────────
class AppTheme {
  // ── Convenience getters (aliases for AppColors) ─────────────────
  static const Color bg         = AppColors.bg0;
  static const Color panel      = AppColors.surface;
  static const Color panelLight = AppColors.surfaceElevated;
  static const Color accent     = AppColors.accent;
  static const Color safe       = AppColors.success;
  static const Color danger     = AppColors.danger;
  static const Color border     = AppColors.border;
  static const Color textBright = AppColors.textPrimary;
  static const Color textDim    = AppColors.textSecondary;
  static const Color primary    = AppColors.primary;

  static Color aqiColor(int aqi) {
    if (aqi <= 50)  return AppColors.success;
    if (aqi <= 100) return AppColors.warning;
    if (aqi <= 150) return const Color(0xFFFF7043);
    if (aqi <= 200) return AppColors.danger;
    if (aqi <= 300) return AppColors.purple;
    return const Color(0xFF8B0000);
  }

  static String aqiLevel(int aqi) {
    if (aqi <= 100) return 'safe';
    if (aqi <= 200) return 'moderate';
    return 'danger';
  }

  static String aqiLabel(int aqi) {
    if (aqi <= 50)  return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  // ── Material 3 ThemeData ─────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg0,
      colorScheme: const ColorScheme.dark(
        brightness:      Brightness.dark,
        primary:         AppColors.primary,
        onPrimary:       Colors.white,
        secondary:       AppColors.accent,
        onSecondary:     Colors.black,
        surface:         AppColors.surface,
        onSurface:       AppColors.textPrimary,
        error:           AppColors.danger,
        onError:         Colors.white,
        outline:         AppColors.border,
        surfaceContainerHighest: AppColors.surfaceHighest,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor:       AppColors.textPrimary,
        displayColor:    AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation:       0,
        scrolledUnderElevation: 0,
        centerTitle:     false,
        iconTheme:       IconThemeData(color: AppColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:   const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:   const BorderSide(color: AppColors.danger),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:  AppColors.primary,
          foregroundColor:  Colors.white,
          elevation:        0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          textStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
        ),
      ),
      cardTheme: CardThemeData(
        color:        AppColors.surface,
        elevation:    0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side:         const BorderSide(color: AppColors.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHighest,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}