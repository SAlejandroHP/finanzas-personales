import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/accounts_repository.dart';
import '../../models/account_model.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../../core/services/finance_service.dart';
/// Provider del repositorio de cuentas
final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  final repo = AccountsRepository();
  
  // Limpia la suscripción cuando el provider se destruye
  ref.onDispose(() {
    repo.dispose();
  });
  
  return repo;
});

/// Provider que obtiene la lista de cuentas del usuario actual
/// Usa StreamProvider para escuchar cambios en tiempo real
final accountsListProvider = StreamProvider<List<AccountModel>>((ref) async* {
  final repo = ref.watch(accountsRepositoryProvider);
  
  // Emite la lista inicial
  final initialAccounts = await repo.getUserAccounts();
  yield initialAccounts;
  
  // Escucha cambios en tiempo real
  await for (final accounts in repo.accountsStream) {
    yield accounts;
  }
});

/// Provider que calcula los saldos reales de las cuentas basándose en transacciones
/// NOTA: Se ha simplificado para confiar en el saldo_actual de la base de datos,
/// el cual es mantenido consistente por FinanceService en tiempo real.
final accountsWithBalanceProvider = Provider<AsyncValue<List<AccountModel>>>((ref) {
  final accountsAsync = ref.watch(accountsListProvider);
  
  return accountsAsync.when(
    data: (accounts) => AsyncValue.data(accounts),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider de la cuenta seleccionada actualmente (para edición)
final selectedAccountProvider = StateProvider<AccountModel?>((ref) => null);

/// Provider que calcula el saldo total disponible (Capital Líquido)
/// Según LOGICA_APP: "Suma del saldo_actual de todas las cuentas (EXCLUYE tarjetas de crédito para no inflar liquidez)"
final totalBalanceProvider = Provider<double>((ref) {
  final accountsAsync = ref.watch(accountsWithBalanceProvider);
  
  return accountsAsync.maybeWhen(
    data: (accounts) {
      // Sumamos solo cuentas que representan dinero real (efectivo, ahorros, inversiones, etc.)
      // Las tarjetas de crédito NO se suman al balance principal porque el crédito no es dinero propio.
      return accounts
          .where((acc) => acc.tipo != 'tarjeta_credito')
          .fold<double>(0.0, (sum, acc) => sum + acc.saldoActual);
    },
    orElse: () => 0.0,
  );
});

/// Provider para el estado de carga de operaciones
final accountsLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider para mensajes de error
final accountsErrorProvider = StateProvider<String?>((ref) => null);

/// Notificador para operaciones de cuentas
class AccountsNotifier extends StateNotifier<AsyncValue<void>> {
  final AccountsRepository _repository;
  final Ref _ref;

  AccountsNotifier(this._repository, this._ref) 
      : super(const AsyncValue.data(null));

  Future<void> createAccount(AccountModel account, {double? limiteCredito, double? deudaActual}) async {
    _setLoading(true);
    _clearError();

    try {
      // Si es TC, el saldo inicial es lo disponible: limite - deuda actual
      AccountModel accountToSave = account;
      if (account.tipo == 'tarjeta_credito' && limiteCredito != null && deudaActual != null) {
        accountToSave = account.copyWith(
          saldoInicial: limiteCredito, // Guardamos el límite como saldo inicial por consistencia con el UI anterior
          saldoActual: limiteCredito - deudaActual,
        );
      }

      await _repository.createAccount(accountToSave);

      // Lógica de tarjeta de crédito: crear deuda asociada automáticamente
      if (account.tipo == 'tarjeta_credito' && limiteCredito != null && deudaActual != null) {
        final debt = DebtModel(
          id: const Uuid().v4(),
          userId: account.userId,
          nombre: "Tarjeta ${account.nombre}",
          montoTotal: limiteCredito,
          montoRestante: deudaActual,
          tipo: 'prestamo_bancario',
          cuentaAsociadaId: account.id,
          estado: 'activa',
          createdAt: DateTime.now(),
        );
        await _ref.read(debtsRepositoryProvider).createDebt(debt);
      }

      state = const AsyncValue.data(null);
      
      // FinanceService: centraliza actualizaciones de todos los providers
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza una cuenta existente
  Future<void> updateAccount(AccountModel account) async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.updateAccount(account);
      state = const AsyncValue.data(null);
      
      // FinanceService: refrescar providers
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Elimina una cuenta
  Future<void> deleteAccount(String id) async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.deleteAccount(id);
      state = const AsyncValue.data(null);
      
      // FinanceService: refrescar providers
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Actualiza el saldo de una cuenta
  Future<void> updateBalance(String accountId, double newBalance) async {
    _setLoading(true);
    _clearError();

    try {
      await _repository.updateAccountBalance(accountId, newBalance);
      state = const AsyncValue.data(null);
      
      // FinanceService: refrescar providers para actualizar Dashboard y listas
      _ref.read(financeServiceProvider).refreshAll();
    } catch (e) {
      _setError(e.toString());
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _ref.read(accountsLoadingProvider.notifier).state = loading;
  }

  void _clearError() {
    _ref.read(accountsErrorProvider.notifier).state = null;
  }

  void _setError(String error) {
    _ref.read(accountsErrorProvider.notifier).state = error;
  }
}

/// Provider del notificador de cuentas
final accountsNotifierProvider = 
    StateNotifierProvider<AccountsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(accountsRepositoryProvider);
  return AccountsNotifier(repository, ref);
});

