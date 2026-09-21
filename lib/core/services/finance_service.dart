import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../features/transactions/models/transaction_model.dart';
import '../../features/accounts/presentation/providers/accounts_provider.dart';
import '../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../features/debts/presentation/providers/debts_provider.dart';
import '../../features/goals/presentation/providers/goals_provider.dart';
import '../../features/categories/presentation/providers/categories_provider.dart';
import '../../features/transactions/presentation/screens/recurring_transactions_screen.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:convert';

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
    // Audit v6: No usamos refreshAll() aquí porque los StreamProviders ya tienen
    // suscripciones Realtime a Supabase. Invalidad aquí forzaba a la app entera a
    // entrar en estado "loading" (spinner) y re-hacer las peticiones de red.
    // Con Realtime, la UI se actualiza sola en ~200ms suavemente.
    final refToUse = ref ?? _ref;
    _syncContextToWidget(refToUse);
  }

  /// Coordina el pago anticipado de una transacción recurrente
  Future<void> processRecurringPayment(String ruleId) async {
    // 1. Obtener la regla recurrente por su ID
    final repository = _ref.read(transactionsRepositoryProvider);
    final recurringRules = await repository.getRecurringTransactions();
    
    TransactionModel? rule;
    for (final r in recurringRules) {
      if (r.id == ruleId) {
        rule = r;
        break;
      }
    }

    if (rule == null) {
      throw Exception('Regla recurrente no encontrada o inactiva');
    }

    // 2. Procesar el pago anticipado (Crea la transacción y actualiza la regla)
    await repository.payRecurringEarly(rule);

    // 3. Sync context (no hacemos refreshAll para evitar spinners globales)
    _syncContextToWidget(_ref);
  }

  /// Invalida todos los providers relacionados usando el Ref interno seguro o uno externo
  void refreshAll([Ref? ref, bool force = false]) {
    // Audit v6: Por defecto force es false para evitar que las mutaciones (agregar, pagar)
    // destruyan los StreamProviders en tiempo real y causen spinners lentos.
    // Solo en Pull-to-refresh enviamos force = true.
    final refToUse = ref ?? _ref;
    
    if (force) {
      refToUse.invalidate(accountsListProvider);
      refToUse.invalidate(accountsWithBalanceProvider);
      refToUse.invalidate(transactionsListProvider);
      refToUse.invalidate(pendingTransactionsProvider); 
      refToUse.invalidate(recentTransactionsProvider); 
      refToUse.invalidate(debtsListProvider);
      refToUse.invalidate(pendingInvitationsProvider);
      refToUse.invalidate(recurringTransactionsProvider);
      refToUse.invalidate(goalsListProvider);
      
      refToUse.invalidate(categoriesListProvider);
      refToUse.invalidate(incomeCategoriesProvider);
      refToUse.invalidate(expenseCategoriesProvider);
    } else {
      // Actualización silenciosa (sin spinners)
      // Empuja los nuevos datos a los StreamControllers locales
      refToUse.read(transactionsRepositoryProvider).refresh();
      refToUse.read(accountsRepositoryProvider).refresh();
      refToUse.read(categoriesRepositoryProvider).refresh();
      
      // Para Debts y Goals que aún no tienen refresh(), los invalidamos
      // Ya que no se usan tan frecuentemente como las transacciones
      refToUse.invalidate(debtsListProvider);
      refToUse.invalidate(goalsListProvider);
      refToUse.invalidate(recurringTransactionsProvider);
    }
    
    // Guardar contexto para la IA en el Widget
    _syncContextToWidget(refToUse);
  }

  Future<void> _syncContextToWidget(Ref ref) async {
    try {
      final accounts = ref.read(accountsListProvider).value ?? [];
      final categories = ref.read(categoriesListProvider).value ?? [];
      
      final contextMap = {
        'accounts': accounts.map((a) => {'id': a.id, 'nombre': a.nombre}).toList(),
        'categories': categories.map((c) => {'id': c.id, 'nombre': c.nombre, 'tipo': c.tipo}).toList(),
      };
      
      await HomeWidget.saveWidgetData('ai_context', jsonEncode(contextMap));
    } catch (e) {
      // Ignorar errores en background
    }
  }
}

final financeServiceProvider = Provider<FinanceService>((ref) => FinanceService(ref));
