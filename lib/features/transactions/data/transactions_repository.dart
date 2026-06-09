import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../../../core/network/supabase_client.dart';
import '../../accounts/models/account_model.dart';
import '../../debts/models/debt_model.dart';

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

  Future<List<TransactionModel>> getUserTransactions() async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      final email = user?.email?.trim().toLowerCase();

      if (userId == null) return [];

      // 1. Obtener IDs de deudas donde el usuario es dueño o invitado aceptado
      final allDebtsResponse = await _supabase
          .from('deudas')
          .select('id')
          .or('user_id.eq.$userId,and(shared_with_email.ilike.${email ?? ''},estado_invitacion.eq.accepted)');
      final allDebtIds = (allDebtsResponse as List).map((d) => d['id'] as String).toList();

      // 2. Obtener IDs de metas donde el usuario es dueño o invitado aceptado
      final allGoalsResponse = await _supabase
          .from('metas')
          .select('id')
          .or('user_id.eq.$userId,and(shared_with_email.ilike.${email ?? ''},estado_invitacion.eq.accepted)');
      final allGoalIds = (allGoalsResponse as List).map((g) => g['id'] as String).toList();

      var query = _supabase.from('transacciones').select();
      
      // Filtramos mis transacciones OR transacciones vinculadas a deudas/metas compartidas
      final List<String> orConditions = ['user_id.eq.$userId'];
      if (allDebtIds.isNotEmpty) {
        final idsStr = allDebtIds.map((id) => '"$id"').join(',');
        orConditions.add('deuda_id.in.($idsStr)');
      }
      if (allGoalIds.isNotEmpty) {
        final idsStr = allGoalIds.map((id) => '"$id"').join(',');
        orConditions.add('meta_id.in.($idsStr)');
      }

      query = query.or(orConditions.join(','));

      final response = await query.order('fecha', ascending: false);

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
      final transactions = await getUserTransactions();
      return transactions.take(limit).toList();
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
        return [];
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

      String estadoValido = transaction.estado;
      if (!['completa', 'pendiente'].contains(estadoValido)) {
        estadoValido = 'completa';
      }

      if (transaction.isRecurring && transaction.recurringRule != null) {
        final nextOccurrence = _calculateNextOccurrence(
          transaction.recurringRule!,
          transaction.fecha,
          weekendAdjustment: transaction.weekendAdjustment,
        );

        final plantilla = transaction.toJson();
        plantilla.remove('id');
        plantilla.remove('created_at');
        plantilla.remove('updated_at');
        plantilla.remove('is_recurring');
        plantilla.remove('recurring_rule');
        plantilla.remove('next_occurrence');
        plantilla.remove('last_occurrence');
        plantilla.remove('is_active');
        
        await _supabase.from('reglas_recurrentes').insert({
          'id': const Uuid().v4(),
          'user_id': userId,
          'plantilla_transaccion': plantilla,
          'frecuencia': transaction.recurringRule,
          'proxima_ocurrencia': nextOccurrence.toIso8601String(),
          'activa': transaction.isActive,
        });

        final txData = transaction.copyWith(
          userId: userId,
          createdAt: DateTime.now(),
          estado: estadoValido,
          isRecurring: false,
          recurringRule: null,
          nextOccurrence: null,
        );

        await _validateDebtPaymentOverflow(txData);
        await _supabase.from('transacciones').insert(txData.toJson());

        if (txData.estado == 'completa') {
          await _syncCascadingEffects(txData);
        }
      } else {
        final txData = transaction.copyWith(
          userId: userId,
          createdAt: DateTime.now(),
          estado: estadoValido,
        );

        await _validateDebtPaymentOverflow(txData);
        await _supabase.from('transacciones').insert(txData.toJson());

        if (txData.estado == 'completa') {
          await _syncCascadingEffects(txData);
        }
      }
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
        return [];
      }

      final response = await _supabase
          .from('reglas_recurrentes')
          .select()
          .eq('user_id', userId)
          .order('proxima_ocurrencia', ascending: true);

      return (response as List).map((row) {
        final plantilla = Map<String, dynamic>.from(row['plantilla_transaccion'] as Map<String, dynamic>);
        
        // Inyectamos los campos obligatorios que fueron removidos al guardar la plantilla
        plantilla['id'] = row['id'];
        plantilla['user_id'] = row['user_id'];
        plantilla['created_at'] = row['created_at'] ?? DateTime.now().toIso8601String();

        return TransactionModel.fromJson(plantilla).copyWith(
          id: row['id'] as String,
          userId: row['user_id'] as String,
          isRecurring: true,
          recurringRule: row['frecuencia'] as String,
          nextOccurrence: row['proxima_ocurrencia'] != null ? DateTime.parse(row['proxima_ocurrencia'] as String) : null,
          isActive: row['activa'] as bool? ?? true,
        );
      }).toList();
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

      final oldRuleData = await _supabase.from('reglas_recurrentes').select().eq('id', transaction.id).maybeSingle();
      if (oldRuleData != null) {
        if (!transaction.isRecurring) {
          await _supabase.from('reglas_recurrentes').delete().eq('id', transaction.id);
          return;
        }

        DateTime? nextOccurrence = transaction.nextOccurrence;
        if (nextOccurrence == null) {
          final oldProximaOcurrenciaStr = oldRuleData['proxima_ocurrencia'] as String?;
          if (oldProximaOcurrenciaStr != null) {
            nextOccurrence = DateTime.tryParse(oldProximaOcurrenciaStr);
          }
          
          if (nextOccurrence == null || oldRuleData['frecuencia'] != transaction.recurringRule) {
             nextOccurrence = _calculateNextOccurrence(
               transaction.recurringRule!,
               transaction.fecha,
               weekendAdjustment: transaction.weekendAdjustment,
             );
          }
        }
        
        final plantilla = transaction.toJson();
        plantilla.remove('id');
        plantilla.remove('created_at');
        plantilla.remove('updated_at');
        plantilla.remove('is_recurring');
        plantilla.remove('recurring_rule');
        plantilla.remove('next_occurrence');
        plantilla.remove('last_occurrence');
        plantilla.remove('is_active');
        
        await _supabase.from('reglas_recurrentes').update({
          'plantilla_transaccion': plantilla,
          'frecuencia': transaction.recurringRule,
          'proxima_ocurrencia': nextOccurrence!.toIso8601String(),
          'activa': transaction.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', transaction.id);
        return;
      }

      final oldTxData = await _supabase.from('transacciones').select().eq('id', transaction.id).single();
      final oldTx = TransactionModel.fromJson(oldTxData);

      if (oldTx.estado == 'completa') {
        await _syncCascadingEffects(oldTx, isUndo: true);
      }

      if (!oldTx.isRecurring && transaction.isRecurring && transaction.recurringRule != null) {
        final nextOccurrence = _calculateNextOccurrence(
          transaction.recurringRule!,
          transaction.fecha,
          weekendAdjustment: transaction.weekendAdjustment,
        );
        
        final plantilla = transaction.toJson();
        plantilla.remove('id');
        plantilla.remove('created_at');
        plantilla.remove('updated_at');
        plantilla.remove('is_recurring');
        plantilla.remove('recurring_rule');
        plantilla.remove('next_occurrence');
        plantilla.remove('last_occurrence');
        plantilla.remove('is_active');
        
        await _supabase.from('reglas_recurrentes').insert({
          'id': const Uuid().v4(),
          'user_id': userId,
          'plantilla_transaccion': plantilla,
          'frecuencia': transaction.recurringRule,
          'proxima_ocurrencia': nextOccurrence.toIso8601String(),
          'activa': true,
        });
      }

      final updatedTransaction = transaction.copyWith(
        userId: userId,
        updatedAt: DateTime.now(),
        isRecurring: false,
        recurringRule: null,
      );

      await _validateDebtPaymentOverflow(updatedTransaction, oldTx: oldTx);

      await _supabase
          .from('transacciones')
          .update(updatedTransaction.toJson())
          .eq('id', transaction.id);
      
      if (updatedTransaction.estado == 'completa') {
        await _syncCascadingEffects(updatedTransaction);
      }
    } catch (e) {
      throw Exception('Error al actualizar transacción: $e');
    }
  }

  /// Elimina una transacción
  Future<void> deleteTransaction(String id) async {
    try {
      final txData = await _supabase.from('transacciones').select().eq('id', id).maybeSingle();
      if (txData != null) {
        final tx = TransactionModel.fromJson(txData);
        if (tx.estado == 'completa') {
          await _syncCascadingEffects(tx, isUndo: true);
        }
        await _supabase.from('transacciones').delete().eq('id', id);
      } else {
        await _supabase.from('reglas_recurrentes').delete().eq('id', id);
      }
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

  /// Calcula el total de gastos de un mes específico (excluyendo transferencias/pagos_deuda neutrales)
  Future<double> getMonthlyExpenses(int year, int month) async {
    try {
      final transactions = await getTransactionsByMonth(year, month);
      return transactions
          .where((t) => t.estado == 'completa') // Requisito extra seguridad
          .where((t) => t.tipo == 'gasto' || (t.tipo == 'pago_deuda' && t.cuentaDestinoId == null) || t.tipo == 'meta_aporte')
          .fold<double>(0.0, (sum, t) => sum + t.monto);
    } catch (e) {
      throw Exception('Error al calcular gastos del mes: $e');
    }
  }

  /// Calcula el total de ingresos de un mes específico (excluyendo ajustes y neutrales)
  Future<double> getMonthlyIncome(int year, int month) async {
    try {
      final transactions = await getTransactionsByMonth(year, month);
      return transactions
          .where((t) => t.estado == 'completa') // Solo transacciones confirmadas
          .where((t) => t.tipo == 'ingreso' && t.tipo != 'ajuste_reconciliacion')
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

      // Verificamos si ya está completa en BD para evitar duplicados
      final currentTxData = await _supabase.from('transacciones').select().eq('id', transaction.id).single();
      final currentTx = TransactionModel.fromJson(currentTxData);
      if (currentTx.estado == 'completa') return;

      final updatedTransaction = transaction.copyWith(
        userId: userId,
        estado: 'completa', // Debe ser 'completa', no 'completada'
        updatedAt: DateTime.now(),
      );
      
      // Validador Anti-Hackeo (Repository-level)
      await _validateDebtPaymentOverflow(updatedTransaction, oldTx: currentTx);

      // Actualiza el estado en la BD
      await _supabase
          .from('transacciones')
          .update(updatedTransaction.toJson())
          .eq('id', transaction.id);

      // Sincronizar efectos
      await _syncCascadingEffects(updatedTransaction);
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

      // 1. Obtener estado actual en BD
      final currentTxData = await _supabase.from('transacciones').select().eq('id', transaction.id).single();
      final currentTx = TransactionModel.fromJson(currentTxData);

      // 2. Si estaba completa, revertir efectos
      if (currentTx.estado == 'completa') {
        await _syncCascadingEffects(currentTx, isUndo: true);
      }

      final updatedTransaction = currentTx.copyWith(
        userId: userId,
        estado: 'pendiente',
        updatedAt: DateTime.now(),
      );

      // 3. Actualiza el estado en la BD
      await _supabase
          .from('transacciones')
          .update(updatedTransaction.toJson())
          .eq('id', transaction.id);
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

  // Helper: Validador Anti-Hackeo de Pasivos
  Future<void> _validateDebtPaymentOverflow(TransactionModel tx, {TransactionModel? oldTx}) async {
    if (tx.estado != 'completa') return;

    // Caso 1: Pago directo a Deuda
    if (tx.tipo == 'pago_deuda' && tx.deudaId != null) {
      final debtData = await _supabase.from('deudas').select().eq('id', tx.deudaId!).maybeSingle();
      if (debtData != null) {
        final debt = DebtModel.fromJson(debtData);
        double actualRestante = debt.montoRestante;
        
        if (oldTx != null && oldTx.estado == 'completa' && oldTx.tipo == 'pago_deuda' && oldTx.deudaId == tx.deudaId) {
           actualRestante += oldTx.monto;
        }

        if (tx.monto > actualRestante + 0.01) {
          throw Exception('ALERTA DE INTEGRIDAD: El monto (${tx.monto}) supera la deuda restante permitida.');
        }
      }
    }

    // Caso 2: Ingreso o Transferencia a Tarjeta de Crédito (Funciona como abono a pasivo)
    final targetAccountId = (tx.tipo == 'ingreso') ? tx.cuentaOrigenId : tx.cuentaDestinoId;
    if (targetAccountId != null) {
      final destAccData = await _supabase.from('cuentas').select().eq('id', targetAccountId).maybeSingle();
      if (destAccData != null) {
        final destAcc = AccountModel.fromJson(destAccData);
        if (destAcc.tipo == 'tarjeta_credito') {
          final debtData = await _supabase.from('deudas').select().eq('cuenta_asociada_id', destAcc.id).maybeSingle();
          if (debtData != null) {
            final debt = DebtModel.fromJson(debtData);
            double actualRestante = debt.montoRestante;
            
            if (oldTx != null && oldTx.estado == 'completa') {
               final oldTarget = (oldTx.tipo == 'ingreso') ? oldTx.cuentaOrigenId : oldTx.cuentaDestinoId;
               if (oldTarget == targetAccountId) {
                 actualRestante += oldTx.monto;
               }
            }

            if (tx.monto > actualRestante + 0.01) {
              throw Exception('ALERTA DE INTEGRIDAD: El monto (${tx.monto}) excede la deuda de la tarjeta asociada.');
            }
          }
        }
      }
    }
  }

  /// Método privado para sincronizar efectos en cascada (Saldos y Deudas)
  /// SIGUE REGLA: Centraliza lógica pero se ejecuta DESPUÉS del cambio en BD de la transacción
  Future<void> _syncCascadingEffects(TransactionModel tx, {bool isUndo = false}) async {
    // 1. Validar que la transacción afecte saldos
    // Solo procesamos transacciones completas para efectos de saldo (salvo si estamos deshaciendo)
    if (tx.estado != 'completa' && !isUndo) return;

    try {
      // --- A. Sync Cuenta Origen ---
      final sourceAccData = await _supabase.from('cuentas').select().eq('id', tx.cuentaOrigenId).maybeSingle();
      if (sourceAccData != null) {
        final sourceAcc = AccountModel.fromJson(sourceAccData);
        bool isSubtraction = (tx.tipo == 'gasto' || tx.tipo == 'transferencia' || tx.tipo == 'pago_deuda');
        if (isUndo) isSubtraction = !isSubtraction;

        double nuevoSaldo = isSubtraction 
            ? sourceAcc.saldoActual - tx.monto 
            : sourceAcc.saldoActual + tx.monto;
        
        await _supabase.from('cuentas').update({'saldo_actual': nuevoSaldo}).eq('id', sourceAcc.id);

        // --- D. Sync Meta (Aporte a Meta) ---
        if (tx.tipo == 'meta_aporte' && tx.metaId != null) {
          final goalData = await _supabase.from('metas').select().eq('id', tx.metaId!).maybeSingle();
          if (goalData != null) {
            final currentAmount = (goalData['current_amount'] as num).toDouble();
            bool isAddition = true;
            if (isUndo) isAddition = false;

            double nuevoMontoActual = isAddition 
                ? currentAmount + tx.monto 
                : currentAmount - tx.monto;
            
            if (nuevoMontoActual < 0) nuevoMontoActual = 0;
            
            await _supabase.from('metas').update({
              'current_amount': nuevoMontoActual,
            }).eq('id', tx.metaId!);
          }
        }

        // Si es TC, sincronizar deuda asociada
        if (sourceAcc.tipo == 'tarjeta_credito') {
          final debtData = await _supabase.from('deudas').select().eq('cuenta_asociada_id', sourceAcc.id).maybeSingle();
          if (debtData != null) {
            final debt = DebtModel.fromJson(debtData);
            bool isPaymentToDebt = tx.tipo == 'ingreso'; // Ingreso a cuenta de TC es pago a deuda
            if (isUndo) isPaymentToDebt = !isPaymentToDebt;
            
            double nuevoMontoRestante = isPaymentToDebt ? debt.montoRestante - tx.monto : debt.montoRestante + tx.monto;
            if (nuevoMontoRestante < 0) nuevoMontoRestante = 0;
            
            // Sincronización de Deuda Compartida: Si tiene shared_id, actualizamos ambos registros
            if (debt.isShared && debt.sharedId != null) {
              await _supabase.from('deudas').update({
                'monto_restante': nuevoMontoRestante,
                'estado': nuevoMontoRestante <= 0 ? 'pagada' : 'activa',
              }).eq('shared_id', debt.sharedId!);
            } else {
              await _supabase.from('deudas').update({
                'monto_restante': nuevoMontoRestante,
                'estado': nuevoMontoRestante <= 0 ? 'pagada' : 'activa',
              }).eq('id', debt.id);
            }
          }
        }
      }

      // --- B. Sync Cuenta Destino ---
      if (tx.cuentaDestinoId != null) {
        final destAccData = await _supabase.from('cuentas').select().eq('id', tx.cuentaDestinoId!).maybeSingle();
        if (destAccData != null) {
          final destAcc = AccountModel.fromJson(destAccData);
          bool isAddition = true;
          if (isUndo) isAddition = false;

          double nuevoSaldo = isAddition 
              ? destAcc.saldoActual + tx.monto 
              : destAcc.saldoActual - tx.monto;
          
          await _supabase.from('cuentas').update({'saldo_actual': nuevoSaldo}).eq('id', destAcc.id);

          if (destAcc.tipo == 'tarjeta_credito') {
            final debtData = await _supabase.from('deudas').select().eq('cuenta_asociada_id', destAcc.id).maybeSingle();
            if (debtData != null) {
              final debt = DebtModel.fromJson(debtData);
              bool isPaymentToDebt = true; // Todo ingreso/transferencia a TC cuenta como pago
              if (isUndo) isPaymentToDebt = false;
              
              double nuevoMontoRestante = isPaymentToDebt ? debt.montoRestante - tx.monto : debt.montoRestante + tx.monto;
              if (nuevoMontoRestante < 0) nuevoMontoRestante = 0;
              
                // Sincronización de Deuda Compartida
                if (debt.isShared && debt.sharedId != null) {
                  await _supabase.from('deudas').update({
                    'monto_restante': nuevoMontoRestante,
                    'estado': nuevoMontoRestante <= 0 ? 'pagada' : 'activa'
                  }).eq('shared_id', debt.sharedId!);
                } else {
                  await _supabase.from('deudas').update({
                    'monto_restante': nuevoMontoRestante,
                    'estado': nuevoMontoRestante <= 0 ? 'pagada' : 'activa'
                  }).eq('id', debt.id);
                }
            }
          }
        }
      }

      // --- C. Sync Deuda Directa (Pago de Deuda externa) ---
      if (tx.tipo == 'pago_deuda' && tx.deudaId != null) {
        final debtData = await _supabase.from('deudas').select().eq('id', tx.deudaId!).maybeSingle();
          if (debtData != null) {
            final debt = DebtModel.fromJson(debtData);
            bool isPayment = true;
            if (isUndo) isPayment = false;
            
            double nuevoMontoRestante = isPayment ? debt.montoRestante - tx.monto : debt.montoRestante + tx.monto;
            if (nuevoMontoRestante < 0) nuevoMontoRestante = 0;
            
            // Sincronización de Deuda Compartida: Actualizar balance del registro único
            // Al ser registro único, esta actualización ya es visible para ambos usuarios.
            await _supabase.from('deudas').update({
              'monto_restante': nuevoMontoRestante,
              'estado': nuevoMontoRestante <= 0 ? 'pagada' : 'activa'
            }).eq('id', debt.id);

            // Nota: Ya no creamos transacciones espejo [SYNC] porque el invitado
            // podrá ver esta misma transacción original gracias al filtro en getUserTransactions.

            // Si la deuda está asociada a otra cuenta de TC ...
            if (debt.cuentaAsociadaId != null) {
              final associatedAccData = await _supabase.from('cuentas').select().eq('id', debt.cuentaAsociadaId!).maybeSingle();
              if (associatedAccData != null) {
                final associatedAcc = AccountModel.fromJson(associatedAccData);
                if (associatedAcc.tipo == 'tarjeta_credito') {
                  double diff = isPayment ? tx.monto : -tx.monto;
                  await _supabase.from('cuentas').update({'saldo_actual': associatedAcc.saldoActual + diff}).eq('id', associatedAcc.id);
                }
              }
            }
          }
        }
    } catch (e) {
      throw Exception('Error en sincronización en cascada: $e');
    }
  }
}
