import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// # REDISEÑO TOTAL UX/UI FINTECH (PALETA "OCEAN LIME")
/// ---------------------------------------------------------------------------
/// Implementación de Temas Ocean Lime.
/// Foco en: Azul Profundo (Primary) y Lima Vibrante (Secondary).
/// ---------------------------------------------------------------------------
abstract class AppTheme {
  /// TEMA CLARO (Default Ocean Lime)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary, // Ocean Blue
        onPrimary: Colors.white,
        secondary: AppColors.secondary, // Lime Vibrant
        onSecondary: AppColors.primary, // Dark Blue on Lime
        tertiary: AppColors.tertiary, // Gold Bright
        onTertiary: AppColors.primary,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight, // #F2F2F2
      textTheme: _buildTextTheme(Brightness.light),
      
      // 🛠️ TAREA 2.1: Inputs (InputDecorationTheme)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16.5, 
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: GoogleFonts.montserrat(
          fontSize: AppColors.bodyMedium,
          color: AppColors.textSecondaryLight,
          fontWeight: FontWeight.w500,
        ),
      ),

      // 🛠️ TAREA 2.2: Botones (ElevatedButtonThemeData)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, // Ocean Blue
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, AppColors.interactiveHeight),
          maximumSize: const Size(double.infinity, AppColors.interactiveHeight),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: AppColors.bodyLarge,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // 🛠️ APP BAR
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: AppColors.titleMedium,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLight,
        ),
      ),

      // CHIPS
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondary.withOpacity(0.15), // Lime Tint
        selectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSmall),
        ),
        labelStyle: GoogleFonts.montserrat(
          fontSize: AppColors.bodySmall,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
        secondaryLabelStyle: GoogleFonts.montserrat(
          fontSize: AppColors.bodySmall,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      
      dividerTheme: DividerThemeData(
        thickness: 1,
        color: AppColors.primary.withOpacity(0.05),
        space: 1,
      ),
    );
  }

  /// TEMA OSCURO
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary, // Deep Blue
        onPrimary: Colors.white,
        secondary: AppColors.secondary, // Lime
        onSecondary: AppColors.primary,
        surface: AppColors.surfaceDark,
        onSurface: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: _buildTextTheme(Brightness.dark),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        hintStyle: GoogleFonts.montserrat(
          fontSize: AppColors.bodyMedium,
          color: AppColors.textSecondaryDark.withOpacity(0.5),
          fontWeight: FontWeight.w500,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, AppColors.interactiveHeight),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          ),
          textStyle: GoogleFonts.montserrat(
            fontSize: AppColors.bodyLarge,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// 🛠️ TAREA 2.3: TextTheme (Construcción Montserrat Ocean Lime)
  static TextTheme _buildTextTheme(Brightness brightness) {
    final Color textColor = brightness == Brightness.dark 
        ? AppColors.textPrimaryDark 
        : AppColors.textPrimaryLight;

    return TextTheme(
      displayLarge: GoogleFonts.montserrat(
        fontSize: AppColors.displayLarge,
        fontWeight: FontWeight.w800,
        color: textColor,
        letterSpacing: -1.0,
      ),
      titleLarge: GoogleFonts.montserrat(
        fontSize: AppColors.titleLarge,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      titleMedium: GoogleFonts.montserrat(
        fontSize: AppColors.titleMedium,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.montserrat(
        fontSize: AppColors.bodyLarge,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.montserrat(
        fontSize: AppColors.bodyMedium,
        fontWeight: FontWeight.w400,
        color: textColor,
      ),
      bodySmall: GoogleFonts.montserrat(
        fontSize: AppColors.bodySmall,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
    );
  }
}
