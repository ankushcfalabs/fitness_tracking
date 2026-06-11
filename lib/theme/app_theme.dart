import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Dark theme colors
  static const bg = Color(0xFF0A0E1A);
  static const surface = Color(0xFF131929);
  static const card = Color(0xFF1C2438);
  static const cardElevated = Color(0xFF252D3D);
  
  // Accent colors
  static const accent = Color(0xFF00E5FF);
  static const accentGreen = Color(0xFF00FF87);
  static const accentOrange = Color(0xFFFF6B35);
  static const accentPurple = Color(0xFF7C4DFF);
  static const accentPink = Color(0xFFFF6B9D);
  
  // Text colors
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8892A4);
  static const textTertiary = Color(0xFF5A6478);
  
  // UI elements
  static const divider = Color(0xFF252D3D);
  static const success = Color(0xFF00FF87);
  static const warning = Color(0xFFFFB800);
  static const error = Color(0xFFFF6B35);
  static const info = Color(0xFF00E5FF);
  
  // Workout state colors
  static const stateActive = Color(0xFF00FF87);
  static const stateRest = Color(0xFFFF6B35);
  static const stateCountdown = Color(0xFF7C4DFF);
  static const stateComplete = Color(0xFF00E5FF);
}

class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 72,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -2,
  );
  
  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -1,
  );
  
  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  
  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  
  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.5,
  );
  
  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.5,
  );
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentGreen,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: AppTypography.titleLarge.copyWith(color: AppColors.textPrimary),
        ),
        cardTheme: CardThemeData(
          color: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
            textStyle: AppTypography.labelLarge,
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
          labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        dividerColor: AppColors.divider,
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 24,
        ),
        useMaterial3: true,
      );
}
