import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/debts_repository.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';
import '../../../../core/services/finance_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';

/// Provider del repositorio de deudas
final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
  // Asegura la recreación del repositorio al cambiar de usuario
  ref.watch(currentUserProvider);
  return DebtsRepository();
});

/// Provider que escucha la lista de deudas en tiempo real
final debtsListProvider = StreamProvider<List<DebtModel>>((ref) {
  final repository = ref.watch(debtsRepositoryProvider);
  return repository.debtsStream;
});

/// Notificador para operaciones de deudas
class DebtsNotifier extends StateNotifier<AsyncValue<void>> {
  final DebtsRepository _repository;
  final Ref _ref;

  DebtsNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> createDebt(DebtModel debt) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createDebt(debt);
      state = const AsyncValue.data(null);
      // FinanceService: refrescar todos los datos relacionados
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteDebt(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteDebt(id);
      state = const AsyncValue.data(null);
      // FinanceService: refrescar todos los datos relacionados
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDebt(DebtModel debt) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateDebt(debt);
      state = const AsyncValue.data(null);
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> acceptInvitation(DebtModel invitation) async {
    state = const AsyncValue.loading();
    try {
      await _repository.acceptInvitation(invitation);
      state = const AsyncValue.data(null);
      // Actualizar todo el estado financiero e invitaciones
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDebtAmount(String debtId, double amount, {required bool isPayment}) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateDebtAmount(debtId, amount, isPayment: isPayment);
      state = const AsyncValue.data(null);
      // Refrescar para ver impacto en disponible
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unlinkDebt(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.unlinkDebt(id);
      state = const AsyncValue.data(null);
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> rejectInvitation(DebtModel invitation) async {
    state = const AsyncValue.loading();
    try {
      await _repository.rejectInvitation(invitation);
      state = const AsyncValue.data(null);
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}


final debtsNotifierProvider = StateNotifierProvider<DebtsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(debtsRepositoryProvider);
  return DebtsNotifier(repository, ref);
});

/// Provider que busca invitaciones pendientes en tiempo real
final pendingInvitationsProvider = StreamProvider<List<DebtModel>>((ref) {
  final repository = ref.watch(debtsRepositoryProvider);
  return repository.pendingInvitationsStream;
});

/// Provider que calcula el monto total de deuda (lo que YO debo - Liability)
final totalDebtsProvider = Provider<double>((ref) {
  final accountsAsync = ref.watch(accountsWithBalanceProvider);
  final debtsAsync = ref.watch(debtsListProvider);

  // Mapear los IDs de las tarjetas de crédito para identificar registros 'sombra'
  final creditCardIds = accountsAsync.maybeWhen(
    data: (accounts) => accounts
        .where((acc) => acc.tipo == 'tarjeta_credito')
        .map((acc) => acc.id)
        .toSet(),
    orElse: () => <String>{},
  );

  // 1. Sumamos deudas explícitas, IGNORANDO los registros sombra de tarjetas de crédito
  // porque esos pueden estar desactualizados.
  double explicitDebts = debtsAsync.maybeWhen(
    data: (debts) => debts
        .where((d) => d.ownerRole == 'borrower' && !creditCardIds.contains(d.cuentaAsociadaId))
        .fold<double>(0.0, (sum, debt) => sum + debt.montoRestante),
    orElse: () => 0.0,
  );

  // 2. Sumamos deudas implícitas de TODAS las tarjetas de crédito usando su saldo real en vivo
  double implicitCreditCardDebts = accountsAsync.maybeWhen(
    data: (accounts) {
      double sum = 0.0;
      for (var acc in accounts) {
        if (acc.tipo == 'tarjeta_credito') {
          // La deuda es el límite (saldoInicial) menos lo disponible (saldoActual)
          double deuda = acc.saldoInicial - acc.saldoActual;
          if (deuda > 0) {
            sum += deuda;
          }
        }
      }
      return sum;
    },
    orElse: () => 0.0,
  );

  return explicitDebts + implicitCreditCardDebts;
});

/// Provider que calcula el monto total que me deben (Assets)
final totalLoansToReceiveProvider = Provider<double>((ref) {
  final debtsAsync = ref.watch(debtsListProvider);
  return debtsAsync.maybeWhen(
    data: (debts) => debts
        .where((d) => d.ownerRole == 'lender')
        .fold<double>(0.0, (sum, debt) => sum + debt.montoRestante),
    orElse: () => 0.0,
  );
});
