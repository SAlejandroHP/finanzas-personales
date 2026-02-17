import 'package:supabase_flutter/supabase_flutter.dart';

/// Interfaz abstracta para el repositorio de autenticación.
/// Define todas las operaciones de autenticación disponibles.
abstract class AuthRepository {
  /// Obtiene el usuario actual autenticado
  User? get currentUser;

  /// Stream que notifica cambios en el estado de autenticación
  Stream<AuthState> get authStateChanges;

  /// Inicia sesión con email y contraseña
  Future<User> signInWithEmailPassword(String email, String password);

  /// Registra un nuevo usuario con email y contraseña
  Future<User> signUpWithEmailPassword(String email, String password);

  /// Inicia sesión con Google
  Future<User> signInWithGoogle();

  /// Inicia sesión con Apple
  Future<User> signInWithApple();

  /// Cierra la sesión actual
  Future<void> signOut();

  /// Envía un email para restablecer contraseña
  Future<void> resetPassword(String email);

  /// Verifica si los biométricos están disponibles
  Future<bool> canAuthenticateWithBiometrics();

  /// Autentica con biométricos (Face ID / Touch ID)
  Future<bool> authenticateWithBiometrics();

  /// Guarda las credenciales para login biométrico
  Future<void> saveBiometricCredentials(String email, String token);

  /// Obtiene las credenciales guardadas para biométricos
  Future<Map<String, String>?> getBiometricCredentials();

  /// Elimina las credenciales biométricas guardadas
  Future<void> clearBiometricCredentials();

  /// Verifica si hay credenciales biométricas guardadas
  Future<bool> hasBiometricCredentials();
}
