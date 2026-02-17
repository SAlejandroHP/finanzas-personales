import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_repository.dart';

/// Implementación concreta del repositorio de autenticación.
/// Usa Supabase como backend y soporta múltiples métodos de autenticación.
///
/// NOTA: Plantilla de correo de confirmación
/// Para personalizar el correo de confirmación de email:
/// 1. Ve a Supabase Dashboard → Proyecto → Authentication → Email Templates
/// 2. Selecciona "Confirm signup" para editar la plantilla
/// 3. Personaliza el asunto (ej: "Bienvenido a Finanzas Personal") y el cuerpo
/// 4. El enlace de confirmación se incluye como {{ .ConfirmationURL }}
/// 5. Guarda los cambios
/// Esto mejora la entrega al ser reconocido como correo legítimo por los proveedores.
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _supabaseClient;
  final GoogleSignIn? _googleSignIn;
  LocalAuthentication? _localAuth;
  final FlutterSecureStorage _secureStorage;

  AuthRepositoryImpl({
    required SupabaseClient supabaseClient,
    GoogleSignIn? googleSignIn,
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
  })  : _supabaseClient = supabaseClient,
        // Solo inicializa GoogleSignIn en plataformas móviles (no web)
        _googleSignIn = googleSignIn ?? (kIsWeb ? null : GoogleSignIn()),
        _localAuth = localAuth,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Obtiene instancia lazy de LocalAuthentication
  LocalAuthentication get _auth {
    _localAuth ??= LocalAuthentication();
    return _localAuth!;
  }

  @override
  User? get currentUser => _supabaseClient.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges =>
      _supabaseClient.auth.onAuthStateChange;

  @override
  Future<User> signInWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Error al iniciar sesión');
      }

      return response.user!;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error inesperado: ${e.toString()}');
    }
  }

  @override
  Future<User> signUpWithEmailPassword(String email, String password) async {
    try {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Error al crear la cuenta');
      }

      return response.user!;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error inesperado: ${e.toString()}');
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    try {
      // Verifica que GoogleSignIn esté disponible (no en web sin configurar)
      if (_googleSignIn == null) {
        throw Exception('Google Sign-In no está disponible en esta plataforma');
      }

      // Inicia el flujo de autenticación con Google
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Login con Google cancelado');
      }

      // Obtiene los tokens de autenticación
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('No se pudo obtener los tokens de Google');
      }

      // Autentica con Supabase usando el token de Google
      final response = await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        throw Exception('Error al autenticar con Google');
      }

      return response.user!;
    } catch (e) {
      throw Exception('Error con Google Sign In: ${e.toString()}');
    }
  }

  @override
  Future<User> signInWithApple() async {
    try {
      // Verifica que sea iOS o macOS
      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
      
      if (kIsWeb || (!isIOS && !isMacOS)) {
        throw Exception('Sign In with Apple solo está disponible en iOS/macOS');
      }

      // Inicia el flujo de autenticación con Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('No se pudo obtener el token de Apple');
      }

      // Autentica con Supabase usando el token de Apple
      final response = await _supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      if (response.user == null) {
        throw Exception('Error al autenticar con Apple');
      }

      return response.user!;
    } on SignInWithAppleAuthorizationException catch (e) {
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          throw Exception('Login con Apple cancelado');
        case AuthorizationErrorCode.failed:
          throw Exception('Login con Apple falló');
        case AuthorizationErrorCode.invalidResponse:
          throw Exception('Respuesta inválida de Apple');
        case AuthorizationErrorCode.notHandled:
          throw Exception('Login con Apple no manejado');
        case AuthorizationErrorCode.unknown:
          throw Exception('Error desconocido con Apple');
        default:
          throw Exception('Error con Apple Sign In: ${e.code}');
      }
    } catch (e) {
      throw Exception('Error con Apple Sign In: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
      // Cierra sesión de Google también si está disponible
      if (_googleSignIn != null) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      throw Exception('Error al cerrar sesión: ${e.toString()}');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Error al enviar email de recuperación: ${e.toString()}');
    }
  }

  @override
  Future<bool> canAuthenticateWithBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Plugin no configurado correctamente, retorna false de forma segura
      return false;
    } catch (e) {
      // Cualquier otro error, retorna false de forma segura
      return false;
    }
  }

  @override
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Autentica para acceder a tu cuenta',
      );
    } on PlatformException catch (e) {
      print('Error de autenticación biométrica: ${e.message}');
      return false;
    } on MissingPluginException {
      // Plugin no configurado, retorna false de forma segura
      print('Plugin de autenticación biométrica no disponible');
      return false;
    } catch (e) {
      print('Error inesperado en autenticación biométrica: $e');
      return false;
    }
  }

  @override
  Future<void> saveBiometricCredentials(String email, String token) async {
    await _secureStorage.write(key: 'biometric_email', value: email);
    await _secureStorage.write(key: 'biometric_token', value: token);
    await _secureStorage.write(key: 'biometric_enabled', value: 'true');
  }

  @override
  Future<Map<String, String>?> getBiometricCredentials() async {
    final email = await _secureStorage.read(key: 'biometric_email');
    final token = await _secureStorage.read(key: 'biometric_token');

    if (email != null && token != null) {
      return {'email': email, 'token': token};
    }

    return null;
  }

  @override
  Future<void> clearBiometricCredentials() async {
    await _secureStorage.delete(key: 'biometric_email');
    await _secureStorage.delete(key: 'biometric_token');
    await _secureStorage.delete(key: 'biometric_enabled');
  }

  @override
  Future<bool> hasBiometricCredentials() async {
    final enabled = await _secureStorage.read(key: 'biometric_enabled');
    return enabled == 'true';
  }

  /// Maneja las excepciones de autenticación de Supabase
  String _handleAuthException(AuthException e) {
    switch (e.message.toLowerCase()) {
      case 'invalid login credentials':
        return 'Email o contraseña incorrectos';
      case 'user already registered':
        return 'Este email ya está registrado';
      case 'email not confirmed':
        return 'Por favor confirma tu email';
      case 'invalid email':
        return 'Email inválido';
      default:
        return e.message;
    }
  }
}
