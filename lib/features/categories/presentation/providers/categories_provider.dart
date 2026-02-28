import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/categories_repository.dart';
import '../../models/category_model.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

/// Provider del repositorio de categorías
final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  // Asegura la recreación del repositorio al cambiar de usuario
  ref.watch(currentUserProvider);
  
  final repo = CategoriesRepository();
  
  // Limpia la suscripción cuando el provider se destruye
  ref.onDispose(() {
    repo.dispose();
  });
  
  return repo;
});

/// Provider que obtiene la lista de todas las categorías del usuario actual
/// Usa StreamProvider para escuchar cambios en tiempo real
final categoriesListProvider = StreamProvider<List<CategoryModel>>((ref) async* {
  final repo = ref.watch(categoriesRepositoryProvider);
  
  // Emite la lista inicial
  final initialCategories = await repo.getUserCategories();
  yield initialCategories;
  
  // Escucha cambios en tiempo real
  await for (final categories in repo.categoriesStream) {
    yield categories;
  }
});

/// Provider que obtiene las categorías de ingresos
final incomeCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) async* {
  final repo = ref.watch(categoriesRepositoryProvider);
  
  // Emite la lista inicial
  final initialCategories = await repo.getCategoriesByType('ingreso');
  yield initialCategories;
  
  // Escucha cambios en tiempo real (todos, pero filtramos por tipo)
  await for (final _ in repo.categoriesStream) {
    final categories = await repo.getCategoriesByType('ingreso');
    yield categories;
  }
});

/// Provider que obtiene las categorías de gastos
final expenseCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) async* {
  final repo = ref.watch(categoriesRepositoryProvider);
  
  // Emite la lista inicial
  final initialCategories = await repo.getCategoriesByType('gasto');
  yield initialCategories;
  
  // Escucha cambios en tiempo real (todos, pero filtramos por tipo)
  await for (final _ in repo.categoriesStream) {
    final categories = await repo.getCategoriesByType('gasto');
    yield categories;
  }
});

/// Provider de la categoría seleccionada actualmente (para edición)
final selectedCategoryProvider = StateProvider<CategoryModel?>((ref) => null);

/// Provider que mantiene el tipo de categoría seleccionado (ingreso/gasto)
final categoryTypeFilterProvider = StateProvider<String>((ref) => 'ingreso');

/// Provider que mantiene la búsqueda de categorías
final categorySearchQueryProvider = StateProvider<String>((ref) => '');
