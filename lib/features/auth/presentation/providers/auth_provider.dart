import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/services/finance_service.dart';

/// Provider del repositorio de autenticación
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    supabaseClient: supabaseClient,
  );
});

/// Provider del usuario actual
final currentUserProvider = StreamProvider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  
  return authRepository.authStateChanges.map((state) => state.session?.user);
});

/// Provider del estado de autenticación (bool)
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.value != null;
});

/// Provider del estado de carga durante autenticación
final authLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider del mensaje de error
final authErrorProvider = StateProvider<String?>((ref) => null);

/// Provider para verificar si se pueden usar biométricos
final canUseBiometricsProvider = FutureProvider<bool>((ref) async {
  try {
    final authRepository = ref.watch(authRepositoryProvider);
    final canAuth = await authRepository.canAuthenticateWithBiometrics();
    final hasCredentials = await authRepository.hasBiometricCredentials();
    return canAuth && hasCredentials;
  } catch (e) {
    // Si hay cualquier error, retorna false de forma segura
    return false;
  }
});

/// Notificador para acciones de autenticación
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthNotifier(this._authRepository, this._ref) : super(const AsyncValue.loading()) {
    // Escucha cambios en el estado de autenticación
    _authRepository.authStateChanges.listen((authState) {
      if (authState.session?.user != null) {
        state = AsyncValue.data(authState.session!.user);
      } else {
        state = const AsyncValue.data(null);
      }
    });
  }

  /// Inicia sesión con email y contraseña
  Future<void> signInWithEmailPassword(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authRepository.signInWithEmailPassword(email, password);
      state = AsyncValue.data(user);
      
      // Pregunta si quiere activar biométricos
      final canBiometric = await _authRepository.canAuthenticateWithBiometrics();
      if (canBiometric) {
        // Guarda las credenciales para uso futuro
        // En producción, guarda el refresh token en lugar de la contraseña
        await _authRepository.saveBiometricCredentials(
          email,
          user.id, // Guarda el ID del usuario como token
        );
      }
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _setLoading(false);
    }
  }

  /// Registra un nuevo usuario
  Future<void> signUpWithEmailPassword(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authRepository.signUpWithEmailPassword(email, password);
      state = AsyncValue.data(user);
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _setLoading(false);
    }
  }

  /// Inicia sesión con Google
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authRepository.signInWithGoogle();
      state = AsyncValue.data(user);
      
      // Guarda credenciales biométricas si es posible
      final canBiometric = await _authRepository.canAuthenticateWithBiometrics();
      if (canBiometric) {
        await _authRepository.saveBiometricCredentials(
          user.email ?? '',
          user.id,
        );
      }
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _setLoading(false);
    }
  }

  /// Inicia sesión con Apple
  Future<void> signInWithApple() async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authRepository.signInWithApple();
      state = AsyncValue.data(user);
      
      // Guarda credenciales biométricas si es posible
      final canBiometric = await _authRepository.canAuthenticateWithBiometrics();
      if (canBiometric) {
        await _authRepository.saveBiometricCredentials(
          user.email ?? '',
          user.id,
        );
      }
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _setLoading(false);
    }
  }

  /// Inicia sesión con biométricos
  Future<void> signInWithBiometrics() async {
    _setLoading(true);
    _clearError();

    try {
      // Primero autentica con biométricos
      final authenticated = await _authRepository.authenticateWithBiometrics();
      
      if (!authenticated) {
        throw Exception('Autenticación biométrica fallida');
      }

      // Obtiene las credenciales guardadas
      final credentials = await _authRepository.getBiometricCredentials();
      if (credentials == null) {
        throw Exception('No hay credenciales guardadas');
      }

      // Refresca la sesión con Supabase
      // En producción, usar refreshSession() en lugar de esto
      final session = _authRepository.currentUser;
      if (session != null) {
        state = AsyncValue.data(session);
      } else {
        throw Exception('No se pudo restaurar la sesión');
      }
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _setLoading(false);
    }
  }

  /// Cierra sesión
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _authRepository.signOut();
      state = const AsyncValue.data(null);
      
      // Invalida todos los providers financieros para limpiar el caché del usuario anterior
      try {
        _ref.read(financeServiceProvider).refreshAll();
      } catch (e) {
        // Ignorar si el provider ya fue disposed
      }
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _setLoading(false);
    }
  }

  /// Restablece contraseña
  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authRepository.resetPassword(email);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza el nombre a mostrar del usuario
  Future<void> updateDisplayName(String displayName) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authRepository.updateDisplayName(displayName);
      state = AsyncValue.data(user);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Deshabilita login biométrico
  Future<void> disableBiometrics() async {
    await _authRepository.clearBiometricCredentials();
  }

  void _setLoading(bool value) {
    _ref.read(authLoadingProvider.notifier).state = value;
  }

  void _setError(String error) {
    _ref.read(authErrorProvider.notifier).state = error;
  }

  void _clearError() {
    _ref.read(authErrorProvider.notifier).state = null;
  }
}

/// Provider del notificador de autenticación
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository, ref);
});
