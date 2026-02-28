import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de tema disponible para la aplicación
enum AppThemeMode {
  light,    // Tema claro
  dark,     // Tema oscuro
  system,   // Acorde al sistema
}

/// Provider para SharedPreferences que será inicializado en el main
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

/// Provider que rastrea si hay un canvas (bottom sheet) abierto
/// Cuando es true, el BottomNavigationBar y FAB deben ocultarse
final isCanvasOpenProvider = StateProvider<bool>((ref) => false);

/// Notificador para el modo de tema que persiste la selección del usuario
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  final SharedPreferences _prefs;
  static const String _themeKey = 'user_theme_mode';

  ThemeNotifier(this._prefs) : super(AppThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    final savedTheme = _prefs.getString(_themeKey);
    if (savedTheme != null) {
      if (savedTheme == AppThemeMode.light.name) state = AppThemeMode.light;
      if (savedTheme == AppThemeMode.dark.name) state = AppThemeMode.dark;
      if (savedTheme == AppThemeMode.system.name) state = AppThemeMode.system;
    }
  }

  void setThemeMode(AppThemeMode mode) {
    state = mode;
    _prefs.setString(_themeKey, mode.name);
  }

  /// Alias para mantener compatibilidad si se usa .state = ...
  set themeState(AppThemeMode mode) => setThemeMode(mode);
}

/// Provider para configurar el modo de tema de la aplicación con persistencia
final themeModeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

/// Provider para controlar la visibilidad de la barra de navegación (Scroll-to-hide)
final isNavbarVisibleProvider = StateProvider<bool>((ref) => true);
