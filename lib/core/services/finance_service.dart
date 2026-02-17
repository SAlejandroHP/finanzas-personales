import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/transactions/models/transaction_model.dart';
import '../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../features/debts/presentation/providers/debts_provider.dart';

// FinanceService: solo invalida providers. La BD se actualiza en los repositories.
class FinanceService {
  final Ref _ref;

  FinanceService(this._ref);

  /// Coordina el refresco después de una transacción
  Future<void> updateAfterTransaction(TransactionModel tx, dynamic ref) async {
    refreshAll(ref);
  }

  /// Coordina el refresco después de un pago a deuda
  Future<void> updateAfterPaymentToDebt(String debtId, double amount, dynamic ref) async {
    refreshAll(ref);
  }

  /// Invalida todos los providers relacionados para forzar recarga en vivo
  void refreshAll(dynamic ref) {
    // Usamos el ref pasado (WidgetRef/Ref) o el interno
    final r = ref ?? _ref;
    
    // Invalidamos los providers clave para regenerar cálculos de saldo y listas
    r.invalidate(accountsListProvider);
    r.invalidate(totalBalanceProvider);
    r.invalidate(monthlyIncomeProvider);
    r.invalidate(monthlyExpensesProvider);
    r.invalidate(recentTransactionsProvider);
    r.invalidate(transactionsListProvider);
    
    // Refrescar también la vista calculada de cuentas
    r.invalidate(accountsWithBalanceProvider);
    
    // Si existe el de deudas de forma global, invalidarlo también
    try {
      r.invalidate(debtsListProvider);
    } catch (_) {}
  }
}

final financeServiceProvider = Provider<FinanceService>((ref) => FinanceService(ref));
