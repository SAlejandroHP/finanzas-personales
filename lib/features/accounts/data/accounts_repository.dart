import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_model.dart';
import '../../../core/network/supabase_client.dart';

/// Repositorio para gestionar las operaciones de cuentas en Supabase.
/// Maneja todas las operaciones CRUD y suscripciones realtime.
class AccountsRepository {
  final SupabaseClient _supabase;
  
  /// Stream controller para emitir actualizaciones en tiempo real
  final _accountsController = StreamController<List<AccountModel>>.broadcast();
  
  /// Stream que emite la lista de cuentas cuando hay cambios
  Stream<List<AccountModel>> get accountsStream => _accountsController.stream;
  
  /// Suscripción al canal de realtime
  RealtimeChannel? _realtimeSubscription;

  AccountsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? supabaseClient {
    _setupRealtimeSubscription();
  }

  /// Configura la suscripción realtime para escuchar cambios en la tabla 'cuentas'
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeSubscription = _supabase
        .channel('cuentas_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cuentas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            // Cuando hay un cambio, recarga todas las cuentas
            final accounts = await getUserAccounts();
            _accountsController.add(accounts);
          },
        )
        .subscribe();
  }

  /// Obtiene todas las cuentas del usuario actual
  Future<List<AccountModel>> getUserAccounts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase
          .from('cuentas')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final accounts = (response as List)
          .map((json) => AccountModel.fromJson(json))
          .toList();

      return accounts;
    } catch (e) {
      throw Exception('Error al obtener cuentas: $e');
    }
  }

  /// Crea una nueva cuenta
  Future<void> createAccount(AccountModel account) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Asegura que los metadatos se establezcan, pero respeta el saldo actual si ya fue calculado
      final accountData = account.copyWith(
          userId: userId,
          saldoActual: account.saldoActual, // Usar el saldo actual que viene en el modelo
          createdAt: DateTime.now(),
      );

      await _supabase.from('cuentas').insert(accountData.toJson());
    } catch (e) {
      throw Exception('Error al crear cuenta: $e');
    }
  }

  /// Actualiza una cuenta existente
  Future<void> updateAccount(AccountModel account) async {
    try {
      final updatedAccount = account.copyWith(
        updatedAt: DateTime.now(),
      );
      
      await _supabase
          .from('cuentas')
          .update(updatedAccount.toJson())
          .eq('id', account.id);
    } catch (e) {
      throw Exception('Error al actualizar cuenta: $e');
    }
  }

  /// Establece una cuenta como predeterminada y desactiva las demás
  Future<void> setDefaultAccount(String accountId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // 1. Quitar el flag de predeterminado a todas las cuentas del usuario
      await _supabase
          .from('cuentas')
          .update({'is_default': false})
          .eq('user_id', userId);

      // 2. Establecer el flag a la cuenta objetivo
      await _supabase
          .from('cuentas')
          .update({'is_default': true})
          .eq('id', accountId);
          
    } catch (e) {
      throw Exception('Error al establecer cuenta predeterminada: $e');
    }
  }

  /// Elimina una cuenta
  Future<void> deleteAccount(String id) async {
    try {
      // 1. Verificar si tiene deudas asociadas
      final deudasResponse = await _supabase
          .from('deudas')
          .select('id')
          .eq('cuenta_asociada_id', id)
          .maybeSingle();
      
      if (deudasResponse != null) {
        throw Exception('No se puede eliminar la cuenta porque tiene deudas o una tarjeta de crédito vinculada. Elimina primero la deuda.');
      }

      // 2. Verificar si tiene transacciones asociadas
      final txResponse = await _supabase
          .from('transacciones')
          .select('id')
          .or('cuenta_origen_id.eq.$id,cuenta_destino_id.eq.$id')
          .limit(1)
          .maybeSingle();

      if (txResponse != null) {
        throw Exception('No se puede eliminar la cuenta porque tiene transacciones registradas. Elimina primero el historial de movimientos.');
      }

      // 3. Finalmente eliminar la cuenta si está limpia
      await _supabase.from('cuentas').delete().eq('id', id);
    } catch (e) {
      // Si es una de nuestras excepciones amigables, la pasamos tal cual
      if (e.toString().contains('No se puede eliminar')) {
        rethrow;
      }
      throw Exception('Error al eliminar cuenta: $e');
    }
  }

  /// Obtiene una cuenta por su ID
  Future<AccountModel?> getAccountById(String id) async {
    try {
      final response = await _supabase
          .from('cuentas')
          .select()
          .eq('id', id)
          .single();

      return AccountModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Actualiza el saldo actual de una cuenta
  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    try {
      await _supabase
          .from('cuentas')
          .update({
            'saldo_actual': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', accountId);
    } catch (e) {
      throw Exception('Error al actualizar saldo: $e');
    }
  }

  // --- CIERRE ---

  /// Cierra las suscripciones cuando ya no se necesitan
  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _accountsController.close();
  }
}

