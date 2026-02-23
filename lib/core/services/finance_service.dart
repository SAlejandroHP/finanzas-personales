import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/transactions/models/transaction_model.dart';
import '../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../features/debts/presentation/providers/debts_provider.dart';

// FinanceService: centraliza la lógica de negocio y la coordinación entre repositories.
// Su función principal es realizar las actualizaciones en cascada (saldos, deudas) 
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
      id: const Uuid().v4(),
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

  /// Coordina el refresco de los providers después de una operación financiera
  /// [isUndo] se mantiene por compatibilidad, pero la lógica ahora reside en Repositorios
  Future<void> updateAfterTransaction(TransactionModel tx, {bool isUndo = false}) async {
    refreshAll();
  }

  /// Invalida todos los providers relacionados usando el Ref interno seguro
  void refreshAll() {
    // Usamos el _ref interno que es global y no se destruye con los widgets
    _ref.invalidate(accountsListProvider);
    _ref.invalidate(totalBalanceProvider);
    _ref.invalidate(monthlyIncomeProvider);
    _ref.invalidate(monthlyExpensesProvider);
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(transactionsListProvider);
    _ref.invalidate(accountsWithBalanceProvider);
    
    // Invalida providers de deudas para mantener consistencia
    try {
      _ref.invalidate(debtsListProvider);
      _ref.invalidate(totalDebtsProvider);
    } catch (_) {}
  }
}

final financeServiceProvider = Provider<FinanceService>((ref) => FinanceService(ref));
