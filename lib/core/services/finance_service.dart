import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/transactions/models/transaction_model.dart';
import '../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../features/debts/presentation/providers/debts_provider.dart';
import '../../features/goals/presentation/providers/goals_provider.dart';
import '../../features/categories/presentation/providers/categories_provider.dart';
import '../../features/transactions/presentation/screens/recurring_transactions_screen.dart';

// FinanceService: centraliza la lógica de negocio y la coordinación entre repositories.
// Su función principal es realizar las actualizaciones en cascada (saldos, deudas, metas) 
// y luego invalidar los providers para refrescar la UI.
class FinanceService {
  final Ref _ref;

  FinanceService(this._ref);

  /// Coordina el pago de una deuda: Crea la transacción y deja que updateAfterTransaction haga la cascada
  Future<void> processDebtPayment({
    required String debtId,
    required double amount,
    required String accountId,
    String? description,
    DateTime? fecha,
  }) async {
    // 1. Crear el modelo de transacción con el tipo 'pago_deuda'
    final transaction = TransactionModel(
      id: Uuid().v4(),
      userId: '', // Se asigna en el repositorio
      tipo: 'pago_deuda',
      monto: amount,
      fecha: fecha ?? DateTime.now(),
      estado: 'completa',
      descripcion: description ?? 'Pago de deuda',
      cuentaOrigenId: accountId,
      deudaId: debtId,
      createdAt: DateTime.now(),
    );

    // 2. Registrar la transacción en el repositorio
    await _ref.read(transactionsRepositoryProvider).createTransaction(transaction);

    // 3. Aplicar efectos en cascada (Saldos de cuentas y Deuda) usando el ref interno
    await updateAfterTransaction(transaction);
  }

  /// Coordina el aporte a una meta: Crea la transacción y deja que updateAfterTransaction haga la cascada
  Future<void> processGoalContribution({
    required String goalId,
    required double amount,
    required String accountId,
    String? description,
    DateTime? fecha,
  }) async {
    // 1. Crear el modelo de transacción con el tipo 'meta_aporte'
    final transaction = TransactionModel(
      id: const Uuid().v4(),
      userId: '', // Se asigna en el repositorio
      tipo: 'meta_aporte',
      monto: amount,
      fecha: fecha ?? DateTime.now(),
      estado: 'completa',
      descripcion: description ?? 'Aporte para mi meta',
      cuentaOrigenId: accountId,
      metaId: goalId,
      createdAt: DateTime.now(),
    );

    // 2. Registrar la transacción en el repositorio
    await _ref.read(transactionsRepositoryProvider).createTransaction(transaction);

    // 3. Aplicar efectos en cascada usando el ref interno
    await updateAfterTransaction(transaction);
  }

  /// Sincroniza una deuda compartida (Lógica stub para Supabase)
  Future<void> syncSharedDebt(String sharedId, double newAmount) async {
    // En una implementación real, esto buscaría el registro vinculado
    // por sharedId que NO pertenezca al usuario actual y lo actualizaría.
    // Por ahora refrescamos para asegurar consistencia local.
    refreshAll();
  }

  /// Coordina el refresco de los providers después de una operación financiera
  Future<void> updateAfterTransaction(TransactionModel tx, {bool isUndo = false, Ref? ref}) async {
    refreshAll(ref);
  }

  /// Invalida todos los providers relacionados usando el Ref interno seguro o uno externo
  void refreshAll([Ref? ref]) {
    // Audit v5: Centralizamos aquí los refrescos que antes estaban dispersos.
    // Usamos el _ref interno si no se pasa uno externo.
    final refToUse = ref ?? _ref;
    
    refToUse.invalidate(accountsListProvider);
    refToUse.invalidate(accountsWithBalanceProvider);
    refToUse.invalidate(transactionsListProvider);
    refToUse.invalidate(pendingTransactionsProvider); // Agregado para reactividad en dashboard
    refToUse.invalidate(recentTransactionsProvider); // Agregado para reactividad en dashboard
    refToUse.invalidate(debtsListProvider);
    refToUse.invalidate(pendingInvitationsProvider);
    refToUse.invalidate(recurringTransactionsProvider);
    
    // Providers de categorías (antes dispersos en CategoryForm)
    refToUse.invalidate(categoriesListProvider);
    refToUse.invalidate(incomeCategoriesProvider);
    refToUse.invalidate(expenseCategoriesProvider);
  }
}

final financeServiceProvider = Provider<FinanceService>((ref) => FinanceService(ref));
