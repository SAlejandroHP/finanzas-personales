import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';
import '../../../core/network/supabase_client.dart';

/// Repositorio para gestionar las operaciones de categorías en Supabase.
/// Maneja todas las operaciones CRUD y suscripciones realtime.
class CategoriesRepository {
  final SupabaseClient _supabase;
  
  /// Stream controller para emitir actualizaciones en tiempo real
  final _categoriesController = StreamController<List<CategoryModel>>.broadcast();
  
  /// Stream que emite la lista de categorías cuando hay cambios
  Stream<List<CategoryModel>> get categoriesStream => _categoriesController.stream;
  
  /// Suscripción al canal de realtime
  RealtimeChannel? _realtimeSubscription;

  CategoriesRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? supabaseClient {
    _setupRealtimeSubscription();
  }

  /// Configura la suscripción realtime para escuchar cambios en la tabla 'categorias'
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeSubscription = _supabase
        .channel('categorias')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'categorias',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            // Cuando hay un cambio, recarga todas las categorías
            final categories = await getUserCategories();
            _categoriesController.add(categories);
          },
        )
        .subscribe();
  }

  /// Obtiene todas las categorías del usuario actual
  Future<List<CategoryModel>> getUserCategories() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase
          .from('categorias')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final categories = (response as List)
          .map((json) => CategoryModel.fromJson(json))
          .toList();

      return categories;
    } catch (e) {
      throw Exception('Error al obtener categorías: $e');
    }
  }

  /// Obtiene categorías por tipo (ingreso o gasto)
  Future<List<CategoryModel>> getCategoriesByType(String tipo) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase
          .from('categorias')
          .select()
          .eq('user_id', userId)
          .eq('tipo', tipo)
          .order('nombre', ascending: true);

      final categories = (response as List)
          .map((json) => CategoryModel.fromJson(json))
          .toList();

      return categories;
    } catch (e) {
      throw Exception('Error al obtener categorías por tipo: $e');
    }
  }

  /// Crea una nueva categoría
  Future<void> createCategory(CategoryModel category) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      final categoryData = category.copyWith(
        userId: userId,
        createdAt: DateTime.now(),
      );

      await _supabase.from('categorias').insert(categoryData.toJson());
      
      // Notificar manualmente a los escuchas locales
      final categories = await getUserCategories();
      _categoriesController.add(categories);
    } catch (e) {
      throw Exception('Error al crear categoría: $e');
    }
  }

  /// Actualiza una categoría existente
  Future<void> updateCategory(CategoryModel category) async {
    try {
      await _supabase
          .from('categorias')
          .update(category.toJson())
          .eq('id', category.id);
          
      // Notificar manualmente a los escuchas locales
      final categories = await getUserCategories();
      _categoriesController.add(categories);
    } catch (e) {
      throw Exception('Error al actualizar categoría: $e');
    }
  }

  /// Elimina una categoría
  Future<void> deleteCategory(String id) async {
    try {
      await _supabase.from('categorias').delete().eq('id', id);
      
      // Notificar manualmente a los escuchas locales
      final categories = await getUserCategories();
      _categoriesController.add(categories);
    } catch (e) {
      throw Exception('Error al eliminar categoría: $e');
    }
  }

  /// Obtiene una categoría por su ID
  Future<CategoryModel?> getCategoryById(String id) async {
    try {
      final response = await _supabase
          .from('categorias')
          .select()
          .eq('id', id)
          .single();

      return CategoryModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Cierra las suscripciones cuando ya no se necesitan
  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _categoriesController.close();
  }
}
