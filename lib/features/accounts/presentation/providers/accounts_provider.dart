import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/accounts_repository.dart';
import '../../models/account_model.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart'; 
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
/// Real-time calculation from transactions to ensure data consistency
final accountsWithBalanceProvider = Provider<AsyncValue<List<AccountModel>>>((ref) {
  final accountsAsync = ref.watch(accountsListProvider);
  final transactionsAsync = ref.watch(transactionsListProvider);
  
  return accountsAsync.when(
    data: (accounts) {
      return transactionsAsync.when(
        data: (transactions) {
          return AsyncValue.data(accounts.map((account) {
            final isTC = account.tipo == 'tarjeta_credito';
            
            // Lógica de saldo base:
            // Para cuentas normales, empezamos con saldoInicial (su capital al crear la cuenta).
            // Para Tarjetas de Crédito, saldoInicial es el LÍMITE.
            // Pero si el usuario tenía deuda al inicio, el saldo disponible real era menor.
            // Para corregir esto dinámicamente:
            double balance = account.saldoInicial;
            
            if (isTC) {
              // Si es TC, calculamos la "Deuda Inicial" que no está en transacciones.
              // En la base de datos, saldoActual representa (Limite - Deuda) al momento de carga.
              // Como queremos que las transacciones SEAN la fuente de verdad, partimos del disponible
              // inicial que el usuario registró (0.90 en tu caso de Nu).
              // Así, el pago de $1,999.10 elevará el disponible a los $2000.00 del límite.
              balance = account.saldoActual; 
            }
            
            for (final tx in transactions) {
              if (tx.estado != 'completa') continue;
              
              // Dinero que sale de esta cuenta
              if (tx.cuentaOrigenId == account.id) {
                if (tx.tipo == 'ingreso') {
                  // Caso raro: Ingreso que se asigna a esta cuenta como origen
                  balance += tx.monto;
                } else {
                  balance -= tx.monto;
                }
              }
              
              // Dinero que entra a esta cuenta
              if (tx.cuentaDestinoId == account.id) {
                balance += tx.monto;
              }
            }
            
            // Lógica de tope para Tarjetas de Crédito: 
            // El crédito disponible no puede ser mayor al límite contratado.
            if (isTC && balance > account.saldoInicial) {
              balance = account.saldoInicial;
            }
            
            // Lógica de piso (opcional): El saldo de debito no debería ser negativo, 
            // pero lo permitimos para reflejar sobregiros si existen.

            return account.copyWith(saldoActual: balance);
          }).toList());
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Provider de la cuenta seleccionada actualmente (para edición)
final selectedAccountProvider = StateProvider<AccountModel?>((ref) => null);

/// Provider que calcula el saldo total disponible (Patrimonio Líquido Inmediato)
/// Según LOGICA_APP: "Suma del saldo_actual de todas las cuentas (incluye crédito disponible)"
final totalBalanceProvider = Provider<double>((ref) {
  final accountsAsync = ref.watch(accountsWithBalanceProvider);
  
  return accountsAsync.maybeWhen(
    data: (accounts) {
      return accounts.fold<double>(0.0, (sum, acc) => sum + acc.saldoActual);
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

