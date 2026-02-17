import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Define los temas de la aplicación (claro y oscuro) utilizando Material 3.
/// Implementa una paleta consistente basada en el color Teal primario.

abstract class AppTheme {
  /// Tema claro de la aplicación
  static ThemeData get lightTheme {
    return ThemeData.light(
      useMaterial3: true,
    ).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      textTheme: _buildTextTheme(Brightness.light),
      scaffoldBackgroundColor: AppColors.backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textSecondary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: AppColors.titleMedium,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.pagePadding, vertical: AppColors.contentGap),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          ),
          elevation: AppColors.cardElevation,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );
  }

  /// Tema oscuro de la aplicación
  /// Corrección: Colores más estilizados y menos oscuro (moderno y elegante)
  static ThemeData get darkTheme {
    return ThemeData.dark(
      useMaterial3: true,
    ).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      textTheme: _buildTextTheme(Brightness.dark),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textSecondary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: AppColors.titleMedium,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppColors.pagePadding, vertical: AppColors.contentGap),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSmall),
          ),
          elevation: AppColors.cardElevation,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: MaterialStateProperty.all(Colors.transparent),
      ),
    );
  }

  /// Construye el TextTheme basado en Montserrat de Google Fonts
  static TextTheme _buildTextTheme(Brightness brightness) {
    final textColor = brightness == Brightness.light
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    final baseTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    return GoogleFonts.montserratTextTheme(baseTheme).copyWith(
      displayLarge: GoogleFonts.montserrat(color: textColor),
      displayMedium: GoogleFonts.montserrat(color: textColor),
      displaySmall: GoogleFonts.montserrat(color: textColor),
      headlineLarge: GoogleFonts.montserrat(color: textColor),
      headlineMedium: GoogleFonts.montserrat(color: textColor),
      headlineSmall: GoogleFonts.montserrat(color: textColor),
      titleLarge: GoogleFonts.montserrat(color: textColor),
      titleMedium: GoogleFonts.montserrat(color: textColor),
      titleSmall: GoogleFonts.montserrat(color: textColor),
      bodyLarge: GoogleFonts.montserrat(color: textColor),
      bodyMedium: GoogleFonts.montserrat(color: textColor),
      bodySmall: GoogleFonts.montserrat(color: textColor),
      labelLarge: GoogleFonts.montserrat(color: textColor),
      labelMedium: GoogleFonts.montserrat(color: textColor),
      labelSmall: GoogleFonts.montserrat(color: textColor),
    );
  }
}
