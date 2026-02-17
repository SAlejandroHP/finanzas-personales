import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente de Supabase inicializado y configurado para la aplicación.
/// Proporciona acceso al cliente de Supabase en toda la app.

// Credenciales de Supabase (comentadas por seguridad)
// const supabaseUrl = 'https://txaikgsomwstkfcwfeov.supabase.co';
// const supabaseAnonKey = 'sb_publishable_nI-YWJokAyCWo9wHBWqaNw_dAWyjVpV';

/// Obtiene la instancia del cliente de Supabase
/// Se debe inicializar en main.dart antes de usarlo
final supabaseClient = Supabase.instance.client;

/// Inicializa Supabase con las credenciales de la aplicación.
/// Debe ser llamado en main() antes de lanzar la app.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: 'https://txaikgsomwstkfcwfeov.supabase.co',
    anonKey: 'sb_publishable_nI-YWJokAyCWo9wHBWqaNw_dAWyjVpV',
    debug: false,
  );
}

/// Clase helper para llamadas a Supabase más seguras
class SupabaseService {
  static final client = Supabase.instance.client;

  /// Obtiene el usuario autenticado actualmente
  static User? getCurrentUser() {
    return client.auth.currentUser;
  }

  /// Obtiene la sesión actual
  static Session? getCurrentSession() {
    return client.auth.currentSession;
  }

  /// Verifica si hay un usuario autenticado
  static bool isAuthenticated() {
    return client.auth.currentUser != null;
  }

  /// Cierra la sesión del usuario
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
