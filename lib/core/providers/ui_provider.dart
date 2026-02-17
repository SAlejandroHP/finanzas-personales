import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de tema disponible para la aplicación
enum AppThemeMode {
  light,    // Tema claro
  dark,     // Tema oscuro
  system,   // Acorde al sistema
}

/// Provider que rastrea si hay un canvas (bottom sheet) abierto
/// Cuando es true, el BottomNavigationBar y FAB deben ocultarse
final isCanvasOpenProvider = StateProvider<bool>((ref) => false);

/// Provider para configurar el modo de tema de la aplicación
/// Almacena la preferencia del usuario: light, dark o system
final themeModeProvider = StateProvider<AppThemeMode>((ref) => AppThemeMode.system);

/// Provider para controlar la visibilidad de la barra de navegación (Scroll-to-hide)
final isNavbarVisibleProvider = StateProvider<bool>((ref) => true);
