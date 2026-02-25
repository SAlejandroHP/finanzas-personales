import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/goal_model.dart';
import '../../../../core/network/supabase_client.dart';

/// Repositorio para gestionar las operaciones de metas en Supabase.
class GoalsRepository {
  final SupabaseClient _supabase;
  
  /// Stream controller para emitir actualizaciones en tiempo real
  final _goalsController = StreamController<List<GoalModel>>.broadcast();
  
  /// Stream que emite la lista de metas cuando hay cambios
  Stream<List<GoalModel>> get goalsStream => _goalsController.stream;
  
  /// Suscripción al canal de realtime
  RealtimeChannel? _realtimeSubscription;

  GoalsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? supabaseClient {
    _setupRealtimeSubscription();
  }

  /// Configura la suscripción realtime para escuchar cambios en la tabla 'metas'
  void _setupRealtimeSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeSubscription = _supabase
        .channel('metas_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'metas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) async {
            // Cuando hay un cambio, recarga todas las metas
            final goals = await getUserGoals();
            _goalsController.add(goals);
          },
        )
        .subscribe();
  }

  /// Cierra la suscripción y controladores
  void dispose() {
    _realtimeSubscription?.unsubscribe();
    _goalsController.close();
  }

  /// Obtiene todas las metas del usuario actual
  Future<List<GoalModel>> getUserGoals() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('metas')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => GoalModel.fromJson(json)).toList();
    } catch (e) {
      print('Error al obtener metas: $e');
      return [];
    }
  }

  /// Crea una nueva meta
  Future<void> createGoal(GoalModel goal) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    try {
      await _supabase.from('metas').insert({
        ...goal.toJson(),
        'user_id': userId,
      });
    } catch (e) {
      print('Error al crear meta: $e');
      rethrow;
    }
  }

  /// Actualiza una meta existente
  Future<void> updateGoal(GoalModel goal) async {
    try {
      await _supabase.from('metas').update({
        ...goal.toJson(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', goal.id);
    } catch (e) {
      print('Error al actualizar meta: $e');
      rethrow;
    }
  }

  /// Elimina una meta
  Future<void> deleteGoal(String id) async {
    try {
      await _supabase.from('metas').delete().eq('id', id);
    } catch (e) {
      print('Error al eliminar meta: $e');
      rethrow;
    }
  }
}
