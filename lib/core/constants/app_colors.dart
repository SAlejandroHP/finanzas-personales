import 'package:flutter/material.dart';

/// # REDISEÑO TOTAL UX/UI FINTECH (PALETA "OCEAN LIME")
/// ---------------------------------------------------------------------------
/// Fuente central de verdad para el sistema de diseño "Ocean Lime".
/// Estándares: Profesionalismo azul profundo y energía lima vibrante.
/// ---------------------------------------------------------------------------

// 1. La Paleta "Ocean Lime" (Fuente de Verdad Privada)
const Color _oceanBlue    = Color(0xFF045A80); // Azul Profundo (Principal)
const Color _limeVibrant  = Color(0xFFC2DD3B); // Lima Vibrante (Secundario)
const Color _goldBright   = Color(0xFFF2C230); // Amarillo Dorado (Terciario)
const Color _bgOffWhite   = Color(0xFFF2F2F2); // Fondo App

abstract class AppColors {
  // ===========================================================================
  // 2. MAPEÓ SEMÁNTICO (Trust & Energy)
  // ===========================================================================
  
  static const Color primary   = _oceanBlue;
  static const Color secondary = _limeVibrant;
  static const Color tertiary  = _goldBright;
  
  // Fondos App
  static const Color backgroundLight = _bgOffWhite;
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  
  // Fondos TEMA OSCURO
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark    = Color(0xFF1E1E1E);
  
  // Colores de Texto
  static const Color textPrimaryLight   = _oceanBlue;
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textPrimaryDark    = Color(0xFFFFFFFF);
  static const Color textSecondaryDark  = _limeVibrant;

  // Semánticos
  static const Color success = _limeVibrant; // El lima ya es color de éxito natural
  static const Color error   = Color(0xFFFB7185); // Rosa/Rojo moderno
  static const Color warning = _goldBright;
  static const Color info    = _oceanBlue;

  // ===========================================================================
  // 3. HOMOGENEIDAD MATEMÁTICA Y TIPOGRÁFICA
  // ===========================================================================
  
  static const double interactiveHeight = 52.0;
  static const double radiusSmall       = 8.0;
  static const double radiusMedium      = 12.0;
  static const double radiusLarge       = 24.0;
  
  // Tipografía Montserrat (Tokens de tamaño)
  static const double displayLarge = 32.0; // w800 - Saldo
  static const double titleLarge   = 24.0; // w700 - Headers
  static const double titleMedium  = 18.0; // w600 - Card Titles
  static const double bodyLarge    = 16.0; // w600 - Inputs/Buttons
  static const double bodyMedium   = 14.0; // w400 - Párrafos
  static const double bodySmall    = 12.0; // w500 - Labels/Chips

  // 🌈 Categorías Ocean Lime
  static const List<Color> categoryColors = [
    _oceanBlue,
    _limeVibrant,
    _goldBright,
    Color(0xFF034A6A), // Darker Ocean
    Color(0xFFA8C232), // Darker Lime
    Color(0xFF5BAAD1), // Lighter Ocean
    Color(0xFFD9EF71), // Lighter Lime
    Color(0xFF94A3B8), // Slate Light
    Color(0xFF0B70A1), // Bright Ocean
    Color(0xFFFBBF24), // Amber
  ];

  // ===========================================================================
  // 4. CAPA DE COMPATIBILIDAD (Legacy Support)
  // ===========================================================================
  static const Color backgroundColor = backgroundLight;
  static const Color surface         = surfaceLight;
  static const Color textPrimary     = textPrimaryLight;
  static const Color textSecondary   = textSecondaryLight;
  static const Color primaryDark     = _oceanBlue;
  static const String primaryHex     = '#045A80';
  static const Color description     = textSecondaryLight;
  
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;
  static const double pagePadding = 20.0;
  static const double cardPadding = 16.0;
  static const double contentGap  = 16.0;
  
  static const double titleSmall = 16.0;
  static const double radiusXLarge   = 24.0;
  static const double radiusCircular = 100.0;
  static const double buttonHeight      = interactiveHeight;
  static const double buttonHeightSmall = 36.0;
  static const double inputHeight       = interactiveHeight;
  static const double iconXSmall = 16.0;
  static const double iconSmall  = 20.0;
  static const double iconMedium = 24.0;
  static const double iconLarge  = 32.0;

  static const LinearGradient tealGradient = LinearGradient(
    colors: [_oceanBlue, _limeVibrant], 
  );
}
