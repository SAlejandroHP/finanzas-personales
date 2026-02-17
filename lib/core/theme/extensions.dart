import 'package:flutter/material.dart';

/// Extensiones útiles para el contexto y temas de la aplicación.

extension ThemeExtension on BuildContext {
  /// Obtiene el ThemeData actual
  ThemeData get theme => Theme.of(this);

  /// Obtiene el ColorScheme actual
  ColorScheme get colorScheme => theme.colorScheme;

  /// Verifica si el tema es oscuro
  bool get isDarkMode => theme.brightness == Brightness.dark;

  /// Obtiene el tamaño de la pantalla
  Size get screenSize => MediaQuery.of(this).size;

  /// Obtiene el ancho de la pantalla
  double get screenWidth => screenSize.width;

  /// Obtiene la altura de la pantalla
  double get screenHeight => screenSize.height;

  /// Obtiene el padding seguro (notch, etc.)
  EdgeInsets get safeAreaPadding => MediaQuery.of(this).padding;

  /// Verifica si el dispositivo es en orientación vertical
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;

  /// Verifica si el dispositivo es en orientación horizontal
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
}

extension TextThemeExtension on TextTheme {
  /// Obtiene los estilos de texto predefinidos de manera más accesible
  TextStyle get heading1 => displayLarge ?? const TextStyle();
  TextStyle get heading2 => displayMedium ?? const TextStyle();
  TextStyle get heading3 => headlineLarge ?? const TextStyle();
  TextStyle get body1 => bodyLarge ?? const TextStyle();
  TextStyle get body2 => bodyMedium ?? const TextStyle();
  TextStyle get caption => bodySmall ?? const TextStyle();
}
