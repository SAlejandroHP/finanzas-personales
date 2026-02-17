import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/debts_repository.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';
import '../../../../core/services/finance_service.dart';

/// Provider del repositorio de deudas
final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
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
      _ref.read(financeServiceProvider).refreshAll(_ref);
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
      _ref.read(financeServiceProvider).refreshAll(_ref);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateDebt(DebtModel debt) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateDebt(debt);
      state = const AsyncValue.data(null);
      // FinanceService: refrescar todos los datos relacionados
      _ref.read(financeServiceProvider).refreshAll(_ref);
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
      _ref.read(financeServiceProvider).refreshAll(_ref);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final debtsNotifierProvider = StateNotifierProvider<DebtsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(debtsRepositoryProvider);
  return DebtsNotifier(repository, ref);
});
