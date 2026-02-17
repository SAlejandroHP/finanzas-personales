import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../data/transactions_repository.dart';
import '../../models/transaction_model.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart'; // Corrección v4
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../../core/services/finance_service.dart';
import './transaction_filters_provider.dart';

/// Provider del repositorio de transacciones
final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final repo = TransactionsRepository();

  // Limpia la suscripción cuando el provider se destruye
  ref.onDispose(() {
    repo.dispose();
  });

  return repo;
});

/// Provider que obtiene la lista de transacciones del usuario actual
/// Usa StreamProvider para escuchar cambios en tiempo real
final transactionsListProvider =
    StreamProvider<List<TransactionModel>>((ref) async* {
  final repo = ref.watch(transactionsRepositoryProvider);

  // Emite la lista inicial
  final initialTransactions = await repo.getUserTransactions();
  yield initialTransactions;

  // Escucha cambios en tiempo real
  await for (final transactions in repo.transactionsStream) {
    yield transactions;
  }
});

/// Provider que filtra las transacciones según el estado de los filtros
final filteredTransactionsProvider = Provider<AsyncValue<List<TransactionModel>>>((ref) {
  final transactionsAsync = ref.watch(transactionsListProvider);
  final filters = ref.watch(transactionFiltersProvider);

  return transactionsAsync.whenData((transactions) {
    return transactions.where((t) {
      // Filtro por estatus
      if (filters.status != null && t.estado != filters.status) {
        return false;
      }
      // Filtro por cuenta
      if (filters.accountId != null && 
          t.cuentaOrigenId != filters.accountId && 
          t.cuentaDestinoId != filters.accountId) {
        return false;
      }
      // Filtro por categoría
      if (filters.categoryId != null && t.categoriaId != filters.categoryId) {
        return false;
      }
      // Filtro por monto
      if (filters.minAmount != null && t.monto < filters.minAmount!) {
        return false;
      }
      if (filters.maxAmount != null && t.monto > filters.maxAmount!) {
        return false;
      }
      // Filtro por fecha
      if (filters.dateRange != null) {
        if (t.fecha.isBefore(filters.dateRange!.start) || 
            t.fecha.isAfter(filters.dateRange!.end)) {
          return false;
        }
      }
      return true;
    }).toList();
  });
});

/// Provider que obtiene las últimas transacciones
final recentTransactionsProvider =
    StreamProvider<List<TransactionModel>>((ref) async* {
  final repo = ref.watch(transactionsRepositoryProvider);

  // Emite las transacciones iniciales
  final initialTransactions = await repo.getRecentTransactions(limit: 5);
  yield initialTransactions;

  // Escucha cambios en tiempo real y retorna solo las últimas 5
  await for (final transactions in repo.transactionsStream.distinct()) {
    yield transactions.take(5).toList();
  }
});

/// Provider que obtiene transacciones completadas
/// Según LOGICA_APP: Independiente de la fecha, si está 'completa' es histórico
final completedTransactionsProvider =
    StreamProvider<List<TransactionModel>>((ref) async* {
  final repo = ref.watch(transactionsRepositoryProvider);
  
  final initialTransactions = await repo.getUserTransactions();
  yield initialTransactions.where((t) => t.estado == 'completa').toList();
  
  // Escucha cambios en tiempo real
  await for (final transactions in repo.transactionsStream.distinct()) {
    yield transactions.where((t) => t.estado == 'completa').toList();
  }
});

/// Provider que obtiene próximas transacciones pendientes
/// Según LOGICA_APP: Independiente de la fecha, si está 'pendiente' es compromiso futuro
final pendingTransactionsProvider =
    StreamProvider<List<TransactionModel>>((ref) async* {
  final repo = ref.watch(transactionsRepositoryProvider);
  
  final initialTransactions = await repo.getUserTransactions();
  yield initialTransactions.where((t) => t.estado == 'pendiente').toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha)); // Ordenadas por fecha para ver vencimientos
  
  // Escucha cambios en tiempo real
  await for (final transactions in repo.transactionsStream.distinct()) {
    yield transactions.where((t) => t.estado == 'pendiente').toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
  }
});

/// Provider que obtiene transacciones por cuenta específica
final transactionsByAccountProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, accountId) async* {
  final repo = ref.watch(transactionsRepositoryProvider);

  final initialTransactions = await repo.getTransactionsByAccount(accountId);
  yield initialTransactions;

  await for (final transactions in repo.transactionsStream) {
    yield transactions
        .where((t) =>
            t.cuentaOrigenId == accountId || t.cuentaDestinoId == accountId)
        .toList();
  }
});


/// Provider para el estado del formulario de transacción
final transactionFormProvider =
    StateProvider<TransactionFormState>((ref) => TransactionFormState());

/// Notificador para el estado del formulario
class TransactionFormState {
  final String tipo;
  final double monto;
  final DateTime fecha;
  final String? descripcion;
  final String? cuentaOrigenId;
  final String? cuentaDestinoId;
  final String? categoriaId;
  final String? deudaId;
  final String? metaId;

  TransactionFormState({
    this.tipo = 'gasto',
    this.monto = 0.0,
    DateTime? fecha,
    this.descripcion,
    this.cuentaOrigenId,
    this.cuentaDestinoId,
    this.categoriaId,
    this.deudaId,
    this.metaId,
  }) : fecha = fecha ?? DateTime.now();

  TransactionFormState copyWith({
    String? tipo,
    double? monto,
    DateTime? fecha,
    String? descripcion,
    String? cuentaOrigenId,
    String? cuentaDestinoId,
    String? categoriaId,
    String? deudaId,
    String? metaId,
  }) {
    return TransactionFormState(
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      descripcion: descripcion ?? this.descripcion,
      cuentaOrigenId: cuentaOrigenId ?? this.cuentaOrigenId,
      cuentaDestinoId: cuentaDestinoId ?? this.cuentaDestinoId,
      categoriaId: categoriaId ?? this.categoriaId,
      deudaId: deudaId ?? this.deudaId,
      metaId: metaId ?? this.metaId,
    );
  }

  void reset() {
    // Se reinicia a través del provider StateNotifier
  }
}

/// Provider que calcula el total de gastos del mes actual (solo transacciones completas)
final monthlyExpensesProvider = Provider<double>((ref) {
  final transactionsAsync = ref.watch(transactionsListProvider);
  final now = DateTime.now();
  
  return transactionsAsync.maybeWhen(
    data: (transactions) {
      return transactions.where((t) => 
        t.estado == 'completa' &&
        t.fecha.year == now.year &&
        t.fecha.month == now.month &&
        // Gastos reales: Salidas de dinero del sistema (compras o pagos a deudas externas)
        // No incluimos transferencias internas entre cuentas propias para evitar doble contabilidad.
        (t.tipo == 'gasto' || (t.tipo == 'deuda_pago' && t.cuentaDestinoId == null))
      ).fold(0.0, (sum, t) => sum + t.monto);
    },
    orElse: () => 0.0,
  );
});

/// Provider que calcula el total de ingresos del mes actual (solo transacciones completas)
final monthlyIncomeProvider = Provider<double>((ref) {
  final transactionsAsync = ref.watch(transactionsListProvider);
  final now = DateTime.now();
  
  return transactionsAsync.maybeWhen(
    data: (transactions) {
      return transactions.where((t) => 
        t.estado == 'completa' &&
        t.fecha.year == now.year &&
        t.fecha.month == now.month &&
        t.tipo == 'ingreso'
      ).fold(0.0, (sum, t) => sum + t.monto);
    },
    orElse: () => 0.0,
  );
});

/// Provider para el estado de carga de operaciones
final transactionsLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider para mensajes de error
final transactionsErrorProvider = StateProvider<String?>((ref) => null);

/// Notificador para operaciones de transacciones
class TransactionsNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionsRepository _repository;
  final Ref _ref;

  TransactionsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Crea una nueva transacción
  Future<void> createTransaction(TransactionModel transaction) async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.createTransaction(transaction);
      
      // Sincronizar deuda si aplica
      await _syncDebt(transaction);

      state = const AsyncValue.data(null);

      // FinanceService: coordina el refresco de todos los providers
      await _ref.read(financeServiceProvider).updateAfterTransaction(transaction, _ref);
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza una transacción existente
  Future<void> updateTransaction(TransactionModel transaction) async {
    _setLoading(true);
    _clearError();

    try {
      // Para un update perfecto, deberíamos revertir la anterior, pero como
      // no tenemos la anterior aquí fácilmente, al menos sincronizamos la nueva.
      // Corrección: Sincronizar deuda (esto es incremental en la BD)
      await _syncDebt(transaction);

      await _repository.updateTransaction(transaction);
      state = const AsyncValue.data(null);

      // FinanceService: coordina el refresco de proveedores
      await _ref.read(financeServiceProvider).updateAfterTransaction(transaction, _ref);
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Elimina una transacción
  Future<void> deleteTransaction(String id) async {
    _setLoading(true);
    _clearError();

    try {
      // 1. Obtener la transacción antes de borrarla para revertir efectos
      final transactions = _ref.read(transactionsListProvider).value ?? [];
      final tx = transactions.firstWhereOrNull((t) => t.id == id);
      
      if (tx != null) {
        await _syncDebt(tx, isUndo: true);
      }

      // 2. Eliminar en Repositorio
      await _repository.deleteTransaction(id);
      state = const AsyncValue.data(null);

      // 3. FinanceService: refrescar todos los datos relacionados
      _ref.read(financeServiceProvider).refreshAll(_ref);
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Marca una transacción como completada (Corrección v2)
  Future<void> markAsComplete(TransactionModel transaction) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedTx = transaction.copyWith(estado: 'completa');
      await _repository.markAsComplete(transaction);
      
      // Sincronizar deuda al completar
      await _syncDebt(updatedTx);

      state = const AsyncValue.data(null);

      // FinanceService: coordina el refresco
      await _ref.read(financeServiceProvider).updateAfterTransaction(updatedTx, _ref);
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Marca una transacción como pendiente
  Future<void> markAsPending(TransactionModel transaction) async {
    _setLoading(true);
    _clearError();

    try {
      // Si estaba completa, debemos revertir el efecto en la deuda
      if (transaction.estado == 'completa') {
        await _syncDebt(transaction, isUndo: true);
      }

      await _repository.markAsPending(transaction);
      state = const AsyncValue.data(null);

      // FinanceService: coordina el refresco
      _ref.read(financeServiceProvider).refreshAll(_ref);
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Sincroniza el monto de las deudas (incluyendo TC) basado en la transacción
  Future<void> _syncDebt(TransactionModel transaction, {bool isUndo = false}) async {
    // Solo sincronizamos si la transacción está comple-mentada o estamos deshaciendo una completa
    if (transaction.estado != 'completa' && !isUndo) return;

    try {
      // 1. Caso: Pago de deuda externa o TC (tipo 'deuda_pago')
      if (transaction.tipo == 'deuda_pago' && transaction.deudaId != null) {
        await _ref.read(debtsNotifierProvider.notifier).updateDebtAmount(
          transaction.deudaId!, 
          transaction.monto, 
          isPayment: !isUndo 
        );
      } 
      // 2. Caso: Gasto o Ingreso en Tarjeta de Crédito (afecta deuda de TC)
      else {
        final accounts = _ref.read(accountsListProvider).value ?? [];
        final account = accounts.firstWhereOrNull((a) => a.id == transaction.cuentaOrigenId);
        
        if (account != null && account.tipo == 'tarjeta_credito') {
          // Buscamos la deuda asociada a esta TC
          final debts = _ref.read(debtsListProvider).value ?? [];
          final associatedDebt = debts.firstWhereOrNull((d) => d.cuentaAsociadaId == account.id);
          
          if (associatedDebt != null) {
            // Si es ingreso -> Pago a TC -> Resta de deuda (isPayment: true)
            // Si es gasto -> Consumo -> Suma a deuda (isPayment: false)
            // isUndo invierte la lógica
            bool isPayment = transaction.tipo == 'ingreso';
            if (isUndo) isPayment = !isPayment;
            
            await _ref.read(debtsNotifierProvider.notifier).updateDebtAmount(
              associatedDebt.id, 
              transaction.monto, 
              isPayment: isPayment 
            );
          }
        }
      }
    } catch (e) {
      // Log error but don't block transaction
      print('Error al sincronizar deuda: $e');
    }
  }

  /// Marca una transacción recurrente como pagada anticipadamente
  Future<void> payRecurringEarly(TransactionModel transaction) async {
    _setLoading(true);
    _clearError();

    try {
      // 1. Ejecutar en repositorio y obtener el histórico
      final historicalTx = await _repository.payRecurringEarly(transaction);
      
      // 2. Usar FinanceService para impactar los saldos
      await _ref.read(financeServiceProvider).updateAfterTransaction(historicalTx, _ref);

      state = const AsyncValue.data(null);
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _ref.read(transactionsLoadingProvider.notifier).state = loading;
  }

  void _clearError() {
    _ref.read(transactionsErrorProvider.notifier).state = null;
  }

  void _setError(String error) {
    _ref.read(transactionsErrorProvider.notifier).state = error;
  }
}

/// Modelo para el resumen de transacciones filtradas
class TransactionSummary {
  final double total;
  final double income;
  final double expenses;

  TransactionSummary({
    required this.total,
    required this.income,
    required this.expenses,
  });
}

/// Provider que calcula el resumen (total, ingresos, gastos) de las transacciones filtradas
final filteredTransactionsSummaryProvider = Provider<TransactionSummary>((ref) {
  final transactionsAsync = ref.watch(filteredTransactionsProvider);
  final filters = ref.watch(transactionFiltersProvider);
  final accountId = filters.accountId;
  
  return transactionsAsync.maybeWhen(
    data: (transactions) {
      double income = 0;
      double expenses = 0;
      
      for (final tx in transactions) {
        if (accountId != null) {
          // VISTA POR CUENTA: Flujo de caja real
          if (tx.cuentaOrigenId == accountId) {
            if (tx.tipo == 'ingreso') income += tx.monto;
            else expenses += tx.monto;
          } else if (tx.cuentaDestinoId == accountId) {
            income += tx.monto;
          }
        } else {
          // VISTA GLOBAL: Para el resumen de la lista de movimientos
          // Consideramos Ingresos y Gastos igual que los providers del Dashboard
          if (tx.tipo == 'ingreso') {
            income += tx.monto;
          } else if (tx.tipo == 'gasto' || (tx.tipo == 'transferencia' && tx.deudaId != null && tx.cuentaDestinoId == null)) {
            expenses += tx.monto;
          }
        }
      }
      
      // El TOTAL debe ser consistente con el Patrimonio Neto del Dashboard si no hay filtros
      double totalDisplay = 0;
      if (accountId == null && !ref.read(_hasAnyFilterProvider(filters))) {
        totalDisplay = ref.watch(totalBalanceProvider);
      } else {
        totalDisplay = income - expenses;
      }
      
      return TransactionSummary(
        total: totalDisplay,
        income: income,
        expenses: expenses,
      );
    },
    orElse: () => TransactionSummary(total: 0, income: 0, expenses: 0),
  );
});

// Helper para detectar si hay filtros activos (excepto el de cuenta que ya manejamos)
final _hasAnyFilterProvider = Provider.family<bool, TransactionFilters>((ref, filters) {
  return filters.status != null ||
      filters.categoryId != null ||
      filters.minAmount != null ||
      filters.maxAmount != null ||
      filters.dateRange != null;
});

/// Provider del notificador de transacciones
final transactionsNotifierProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(transactionsRepositoryProvider);
  return TransactionsNotifier(repository, ref);
});
