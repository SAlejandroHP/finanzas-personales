import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/goals_repository.dart';
import '../../models/goal_model.dart';
import '../../../../core/services/finance_service.dart';

/// Provider del repositorio de metas
final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  final repo = GoalsRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Provider que obtiene la lista de metas en tiempo real
final goalsListProvider = StreamProvider<List<GoalModel>>((ref) async* {
  final repo = ref.watch(goalsRepositoryProvider);
  
  // Emite la lista inicial
  final initialGoals = await repo.getUserGoals();
  yield initialGoals;
  
  // Escucha cambios en tiempo real
  await for (final goals in repo.goalsStream) {
    yield goals;
  }
});

/// Provider que calcula el monto total ahorrado en todas las metas
final totalGoalsSavedProvider = Provider<double>((ref) {
  final goalsAsync = ref.watch(goalsListProvider);
  return goalsAsync.maybeWhen(
    data: (goals) => goals.fold<double>(0.0, (sum, g) => sum + g.currentAmount),
    orElse: () => 0.0,
  );
});

/// Provider de la meta seleccionada actualmente
final selectedGoalProvider = StateProvider<GoalModel?>((ref) => null);

/// Notificador para operaciones de metas
class GoalsNotifier extends StateNotifier<AsyncValue<void>> {
  final GoalsRepository _repository;
  final Ref _ref;

  GoalsNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<void> createGoal(GoalModel goal) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createGoal(goal);
      _ref.read(financeServiceProvider).refreshAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateGoal(GoalModel goal) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateGoal(goal);
      _ref.read(financeServiceProvider).refreshAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteGoal(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteGoal(id);
      _ref.read(financeServiceProvider).refreshAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final goalsNotifierProvider = StateNotifierProvider<GoalsNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(goalsRepositoryProvider);
  return GoalsNotifier(repo, ref);
});
