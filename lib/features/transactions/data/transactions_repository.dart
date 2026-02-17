import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../../../core/network/supabase_client.dart';

/// Repositorio para gestionar las operaciones de transacciones en Supabase.
/// Maneja todas las operaciones CRUD y suscripciones realtime.
/// También actualiza los saldos de las cuentas cuando se crean/actualizan transacciones.
class TransactionsRepository {
  final SupabaseClient _supabase;

  /// Stream controller para emitir actualizaciones en tiempo real
  final _transactionsController =
      StreamController<List<TransactionModel>>.broadcast();

  /// Stream que emite la lista de transacciones cuando hay cambios
  Stream<List<TransactionModel>> get transactionsStream =>
      _transactionsController.stream;

  /// Suscripción al canal de realtime
  RealtimeChannel? _realtimeSubscription;

  TransactionsRepository({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? supabaseClient {
    _setupRealtimeSubscription();
  }

  /// Configura la suscripción realtime para escuchar cambios en la tabla 'transacciones'
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeSubscription = _supabase
        .channel('transacciones_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transacciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            // Cuando hay un cambio, recarga todas las transacciones
            final transactions = await getUserTransactions();
            _transactionsController.add(transactions);
          },
        )
        .subscribe();
  }

  /// Obtiene todas las transacciones del usuario actual
  Future<List<TransactionModel>> getUserTransactions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase
          .from('transacciones')
          .select()
          .eq('user_id', userId)
          .order('fecha', ascending: false);

      final transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();

      return transactions;
    } catch (e) {
      throw Exception('Error al obtener transacciones: $e');
    }
  }

  /// Obtiene las últimas N transacciones del usuario
  Future<List<TransactionModel>> getRecentTransactions({int limit = 5}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase
          .from('transacciones')
          .select()
          .eq('user_id', userId)
          .order('fecha', ascending: false)
          .limit(limit);

      final transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();

      return transactions;
    } catch (e) {
      throw Exception('Error al obtener transacciones recientes: $e');
    }
  }

  /// Obtiene transacciones de un mes específico
  Future<List<TransactionModel>> getTransactionsByMonth(
    int year,
    int month,
  ) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0);

      final response = await _supabase
          .from('transacciones')
          .select()
          .eq('user_id', userId)
          .gte('fecha', startDate.toIso8601String())
          .lte('fecha', endDate.toIso8601String())
          .order('fecha', ascending: false);

      final transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();

      return transactions;
    } catch (e) {
      throw Exception('Error al obtener transacciones del mes: $e');
    }
  }

  /// Crea una nueva transacción y actualiza los saldos de las cuentas
  /// Si es recurrente, calcula la próxima ocurrencia
  Future<void> createTransaction(TransactionModel transaction) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      // Corrección v3: Validar estado antes de insertar (CHECK constraint)
      String estadoValido = transaction.estado;
      if (!['completa', 'pendiente'].contains(estadoValido)) {
        estadoValido = 'completa'; // Default seguro
      }

      // Calcular next_occurrence si es recurrente
      DateTime? nextOccurrence = transaction.nextOccurrence;
      if (transaction.isRecurring && transaction.recurringRule != null) {
        // La primera ocurrencia es la fecha de la transacción
        // La siguiente se calcula a partir de esa fecha
        nextOccurrence = _calculateNextOccurrence(
          transaction.recurringRule!,
          transaction.fecha,
          weekendAdjustment: transaction.weekendAdjustment,
        );
      }

      final txData = transaction.copyWith(
        userId: userId,
        createdAt: DateTime.now(),
        estado: estadoValido, // Asegurar que es válido
        nextOccurrence: nextOccurrence,
      );

      // Inserta la transacción
      await _supabase.from('transacciones').insert(txData.toJson());

      // La actualización de saldos ahora se maneja vía FinanceService desde el Notifier/UI
    } catch (e) {
      throw Exception('Error al crear transacción: $e');
    }
  }

  /// Calcula la fecha de la próxima ocurrencia basada en la regla
  DateTime _calculateNextOccurrence(String rule, DateTime lastDate, {bool weekendAdjustment = false}) {
    DateTime nextDate;
    
    if (rule == 'quincenal') {
      // 15 y último día del mes
      final lastDayThisMonth = DateTime(lastDate.year, lastDate.month + 1, 0).day;
      
      if (lastDate.day < 15) {
        nextDate = DateTime(lastDate.year, lastDate.month, 15);
      } else if (lastDate.day < lastDayThisMonth) {
        nextDate = DateTime(lastDate.year, lastDate.month, lastDayThisMonth);
      } else {
        nextDate = DateTime(lastDate.year, lastDate.month + 1, 15);
      }
    } else if (rule.startsWith('monthly_day_')) {
      try {
        final day = int.parse(rule.split('_').last);
        int nextMonth = lastDate.month;
        int nextYear = lastDate.year;

        if (lastDate.day < day) {
          // Es este mes
        } else {
          nextMonth++;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
        }

        final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final targetDay = day > lastDayOfNextMonth ? lastDayOfNextMonth : day;
        nextDate = DateTime(nextYear, nextMonth, targetDay);
      } catch (e) {
        nextDate = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
      }
    } else {
      // Fallback simple
      nextDate = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
    }

    // Aplicar ajuste de fin de semana si está activado
    if (weekendAdjustment) {
      if (nextDate.weekday == DateTime.saturday) {
        nextDate = nextDate.subtract(const Duration(days: 1)); // Viernes
      } else if (nextDate.weekday == DateTime.sunday) {
        nextDate = nextDate.subtract(const Duration(days: 2)); // Viernes
      }
    }

    return nextDate;
  }

  /// Obtiene las reglas de transacciones recurrentes (donde is_recurring = true)
  Future<List<TransactionModel>> getRecurringTransactions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase
          .from('transacciones')
          .select()
          .eq('user_id', userId)
          .eq('is_recurring', true)
          .order('next_occurrence', ascending: true);

      final transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();

      return transactions;
    } catch (e) {
      throw Exception('Error al obtener transacciones recurrentes: $e');
    }
  }

  /// Procesa transacciones automáticas (Placeholder)
  Future<void> processRecurringTransactions() async {
      // TODO: Implementar lógica para generar transacciones cuando hoy >= next_occurrence
      // 1. Buscar reglas donde next_occurrence <= hoy y auto_complete = true (o todas y crear pendientes)
      // 2. Crear nueva transacción copiando datos
      // 3. Actualizar next_occurrence de la regla
  }

  /// Actualiza una transacción existente
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final updatedTransaction = transaction.copyWith(
        userId: userId,
        updatedAt: DateTime.now(),
      );

      // Actualizar en la base de datos
      await _supabase
          .from('transacciones')
          .update(updatedTransaction.toJson())
          .eq('id', transaction.id);
      
      // La actualización de saldos ahora se maneja vía FinanceService
    } catch (e) {
      throw Exception('Error al actualizar transacción: $e');
    }
  }

  /// Elimina una transacción
  Future<void> deleteTransaction(String id) async {
    try {
      await _supabase.from('transacciones').delete().eq('id', id);
      // La actualización de saldos ahora se maneja vía FinanceService
    } catch (e) {
      throw Exception('Error al eliminar transacción: $e');
    }
  }

  /// Obtiene transacciones por cuenta
  Future<List<TransactionModel>> getTransactionsByAccount(
      String accountId) async {
    try {
      final response = await _supabase
          .from('transacciones')
          .select()
          .or(
            'cuenta_origen_id.eq.$accountId,cuenta_destino_id.eq.$accountId',
          )
          .order('fecha', ascending: false);

      final transactions = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();

      return transactions;
    } catch (e) {
      throw Exception('Error al obtener transacciones de cuenta: $e');
    }
  }

  /// Calcula el total de gastos de un mes específico
  Future<double> getMonthlyExpenses(int year, int month) async {
    try {
      final transactions = await getTransactionsByMonth(year, month);
      return transactions
          .where((t) => t.tipo == 'gasto')
          .fold<double>(0.0, (sum, t) => sum + t.monto);
    } catch (e) {
      throw Exception('Error al calcular gastos del mes: $e');
    }
  }

  /// Calcula el total de ingresos de un mes específico
  Future<double> getMonthlyIncome(int year, int month) async {
    try {
      final transactions = await getTransactionsByMonth(year, month);
      return transactions
          .where((t) => t.tipo == 'ingreso')
          .fold<double>(0.0, (sum, t) => sum + t.monto);
    } catch (e) {
      throw Exception('Error al calcular ingresos del mes: $e');
    }
  }

  /// Corrección: Marca una transacción como completada y actualiza saldos
  /// Corrección: Estado debe ser 'completa' (no 'completada') para cumplir con CHECK constraint
  Future<void> markAsComplete(TransactionModel transaction) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final updatedTransaction = transaction.copyWith(
        userId: userId,
        estado: 'completa', // Debe ser 'completa', no 'completada'
        updatedAt: DateTime.now(),
      );

      // Actualiza el estado en la BD
      await _supabase
          .from('transacciones')
          .update(updatedTransaction.toJson())
          .eq('id', transaction.id);

      // La actualización de saldos ahora se maneja vía FinanceService
    } catch (e) {
      throw Exception('Error al marcar transacción como completada: $e');
    }
  }

  /// Marca una transacción como pendiente y revierte los saldos
  Future<void> markAsPending(TransactionModel transaction) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final updatedTransaction = transaction.copyWith(
        userId: userId,
        estado: 'pendiente',
        updatedAt: DateTime.now(),
      );

      // Actualiza el estado en la BD
      await _supabase
          .from('transacciones')
          .update(updatedTransaction.toJson())
          .eq('id', transaction.id);

      // La actualización de saldos ahora se maneja vía FinanceService
    } catch (e) {
      throw Exception('Error al marcar transacción como pendiente: $e');
    }
  }

  /// Marca una transacción recurrente como pagada anticipadamente y retorna la transacción histórica creada
  Future<TransactionModel> payRecurringEarly(TransactionModel transaction) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final hoy = DateTime.now();
      
      // 1. Crear registro histórico del pago realizado HOY
      final historico = transaction.copyWith(
        id: const Uuid().v4(),
        fecha: hoy,
        estado: 'completa',
        isRecurring: false, // El histórico no es recurrente
        nextOccurrence: null,
      );
      
      // Insertar usando el método que ya tenemos (que ahora es simple insert)
      await _supabase.from('transacciones').insert(historico.toJson());

      // 2. Actualizar la regla original con la próxima fecha
      final nextOcc = _calculateNextOccurrence(
        transaction.recurringRule ?? 'monthly_day_13', 
        transaction.nextOccurrence ?? transaction.fecha,
        weekendAdjustment: transaction.weekendAdjustment,
      );

      final updatedRule = transaction.copyWith(
        userId: userId,
        lastOccurrence: hoy,
        nextOccurrence: nextOcc,
        updatedAt: hoy,
      );

      await updateTransaction(updatedRule);
      
      return historico;
    } catch (e) {
      throw Exception('Error al pagar anticipado: $e');
    }
  }

  /// Cierra las suscripciones cuando ya no se necesitan
  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _transactionsController.close();
  }
}
