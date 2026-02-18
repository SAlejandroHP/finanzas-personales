import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/transactions/models/transaction_model.dart';
import '../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../features/debts/presentation/providers/debts_provider.dart';
import '../../features/accounts/models/account_model.dart';
import '../../features/debts/models/debt_model.dart';

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

  /// Coordina el refresco y las actualizaciones en cascada después de una transacción genérica
  /// [isUndo] permite revertir el efecto de una transacción
  Future<void> updateAfterTransaction(TransactionModel tx, {bool isUndo = false}) async {
    // Solo procesamos transacciones completas para efectos de saldo.
    if (tx.estado != 'completa' && !isUndo) {
      refreshAll();
      return;
    }

    try {
      final accRepo = _ref.read(accountsRepositoryProvider);
      final debtRepo = _ref.read(debtsRepositoryProvider);

      // --- 1. Sincronizar Cuenta Origen ---
      final sourceAcc = await accRepo.getAccountById(tx.cuentaOrigenId);
      if (sourceAcc != null) {
        bool isSubtraction = (tx.tipo == 'gasto' || tx.tipo == 'transferencia' || tx.tipo == 'pago_deuda');
        if (isUndo) isSubtraction = !isSubtraction;

        double nuevoSaldo = isSubtraction 
            ? sourceAcc.saldoActual - tx.monto 
            : sourceAcc.saldoActual + tx.monto;
            
        await accRepo.updateAccountBalance(sourceAcc.id, nuevoSaldo);

        if (sourceAcc.tipo == 'tarjeta_credito') {
          final debts = await debtRepo.getUserDebts();
          // Usamos una búsqueda manual para mayor seguridad en Web (JSArray error)
          DebtModel? associatedDebt;
          for (final d in debts) {
            if (d.cuentaAsociadaId == sourceAcc.id) {
              associatedDebt = d;
              break;
            }
          }
          
          if (associatedDebt != null) {
            bool isPayment = tx.tipo == 'ingreso';
            if (isUndo) isPayment = !isPayment;
            await debtRepo.updateDebtAmount(associatedDebt.id, tx.monto, isPayment: isPayment);
          }
        }
      }

      // --- 2. Sincronizar Cuenta Destino ---
      if (tx.cuentaDestinoId != null) {
        final destAcc = await accRepo.getAccountById(tx.cuentaDestinoId!);
        if (destAcc != null) {
          bool isAddition = true;
          if (isUndo) isAddition = false;

          double nuevoSaldo = isAddition 
              ? destAcc.saldoActual + tx.monto 
              : destAcc.saldoActual - tx.monto;
              
          await accRepo.updateAccountBalance(destAcc.id, nuevoSaldo);

          if (destAcc.tipo == 'tarjeta_credito') {
            final debts = await debtRepo.getUserDebts();
            DebtModel? associatedDebt;
            for (final d in debts) {
              if (d.cuentaAsociadaId == destAcc.id) {
                associatedDebt = d;
                break;
              }
            }
            if (associatedDebt != null) {
              bool isPayment = true; 
              if (isUndo) isPayment = false;
              await debtRepo.updateDebtAmount(associatedDebt.id, tx.monto, isPayment: isPayment);
            }
          }
        }
      }

      // --- 3. Sincronizar Deuda Directa ---
      if (tx.tipo == 'pago_deuda' && tx.deudaId != null) {
        final debt = await debtRepo.getDebtById(tx.deudaId!);
        if (debt != null) {
          // Si el pago no fue a través de una cuenta destino (que ya se habría sincronizado en el paso 2)
          if (tx.cuentaDestinoId == null) {
            bool isPayment = true;
            if (isUndo) isPayment = false;
            
            // A. Actualizar el monto restante de la deuda
            await debtRepo.updateDebtAmount(debt.id, tx.monto, isPayment: isPayment);

            // B. Si la deuda está asociada a una cuenta (ej. Tarjeta de Crédito), actualizar su saldo disponible
            if (debt.cuentaAsociadaId != null) {
              final associatedAcc = await accRepo.getAccountById(debt.cuentaAsociadaId!);
              if (associatedAcc != null && associatedAcc.tipo == 'tarjeta_credito') {
                // Pago a deuda de TC -> Aumenta saldo disponible
                double diff = isPayment ? tx.monto : -tx.monto;
                await accRepo.updateAccountBalance(associatedAcc.id, associatedAcc.saldoActual + diff);
              }
            }
          }
        }
      }

    } catch (e) {
      print('FinanceService: Error en actualización en cascada: $e');
    }

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
    
    try {
      _ref.invalidate(debtsListProvider);
    } catch (_) {}
  }
}

final financeServiceProvider = Provider<FinanceService>((ref) => FinanceService(ref));
