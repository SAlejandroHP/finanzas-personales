import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/goal_model.dart';
import '../../../../core/network/supabase_client.dart';

/// Repositorio para gestionar las operaciones de metas en Supabase.
class GoalsRepository {
  final SupabaseClient _supabase;

  GoalsRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? supabaseClient;

  /// Obtiene todas las metas del usuario actual
  Future<List<GoalModel>> getUserGoals() async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id;
    final email = user?.email?.trim().toLowerCase();

    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('metas')
          .select()
          .or(
            'user_id.eq.$userId,and(shared_with_email.ilike.$email,estado_invitacion.eq.accepted)',
          )
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => GoalModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Crea una nueva meta
  Future<void> createGoal(GoalModel goal) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    String estadoInvitacion = goal.estadoInvitacion;
    String? sharedWithEmail = goal.sharedWithEmail?.trim().toLowerCase();

    if (goal.isShared &&
        (sharedWithEmail?.isNotEmpty ?? false) &&
        estadoInvitacion == 'none') {
      estadoInvitacion = 'pending';
    }

    try {
      final goalData = goal.copyWith(
        estadoInvitacion: estadoInvitacion,
        sharedWithEmail: sharedWithEmail,
      );

      await _supabase.from('metas').insert({
        ...goalData.toJson(),
        'user_id': userId,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Actualiza una meta existente
  Future<void> updateGoal(GoalModel goal) async {
    try {
      String estadoInvitacion = goal.estadoInvitacion;
      String? sharedWithEmail = goal.sharedWithEmail?.trim().toLowerCase();

      if (goal.isShared &&
          (sharedWithEmail?.isNotEmpty ?? false) &&
          estadoInvitacion == 'none') {
        estadoInvitacion = 'pending';
      }

      final updateData =
          {
              ...goal
                  .copyWith(
                    estadoInvitacion: estadoInvitacion,
                    sharedWithEmail: sharedWithEmail,
                  )
                  .toJson(),
              'updated_at': DateTime.now().toIso8601String(),
            }
            ..remove('id')
            ..remove('user_id')
            ..remove('created_at');

      await _supabase.from('metas').update(updateData).eq('id', goal.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Elimina una meta
  Future<void> deleteGoal(String id) async {
    try {
      await _supabase.from('metas').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  /// Stream de cambios en tiempo real
  Stream<List<GoalModel>> get goalsStream {
    final user = _supabase.auth.currentUser;
    final userId = user?.id;
    final email = user?.email?.trim().toLowerCase();

    if (userId == null) return Stream.value([]);

    return _supabase
        .from('metas')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (data) => data
              .where((json) {
                final ownerId = json['user_id'] as String?;
                final invitedEmail = (json['shared_with_email'] as String?)
                    ?.toLowerCase();
                final status = json['estado_invitacion'] as String?;

                return ownerId == userId ||
                    (invitedEmail == email && status == 'accepted');
              })
              .map((json) => GoalModel.fromJson(json))
              .toList(),
        );
  }

  /// Obtiene metas compartidas invitadas al email del usuario pero no aceptadas aún
  Future<List<GoalModel>> getPendingInvitations() async {
    try {
      final user = _supabase.auth.currentUser;
      final email = user?.email?.trim().toLowerCase();

      if (email == null) return [];

      final invitedResponse = await _supabase
          .from('metas')
          .select()
          .ilike('shared_with_email', email)
          .eq('estado_invitacion', 'pending');

      return (invitedResponse as List)
          .map((json) => GoalModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream de invitaciones pendientes para notificaciones en tiempo real
  Stream<List<GoalModel>> get pendingInvitationsStream {
    final user = _supabase.auth.currentUser;
    final email = user?.email?.trim().toLowerCase();

    if (email == null) return Stream.value([]);

    return _supabase
        .from('metas')
        .stream(primaryKey: ['id'])
        .eq('estado_invitacion', 'pending')
        .map(
          (data) => data
              .where(
                (json) =>
                    (json['shared_with_email'] as String?)?.toLowerCase() ==
                    email,
              )
              .map((json) => GoalModel.fromJson(json))
              .toList(),
        );
  }

  /// Acepta una invitación
  Future<void> acceptInvitation(GoalModel invitation) async {
    try {
      await _supabase
          .from('metas')
          .update({'estado_invitacion': 'accepted'})
          .eq('id', invitation.id);
    } catch (e) {
      throw Exception('Error al aceptar invitación a meta: $e');
    }
  }

  /// Rechaza una invitación indicándolo en el registro original
  Future<void> rejectInvitation(GoalModel invitation) async {
    try {
      await _supabase
          .from('metas')
          .update({'estado_invitacion': 'rejected'})
          .eq('id', invitation.id);
    } catch (e) {
      throw Exception('Error al rechazar invitación a meta: $e');
    }
  }

  /// Desvincula o abandona una meta compartida
  Future<void> unlinkGoal(GoalModel goal) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final isGuest = user.id != goal.userId;

      // Limpia los datos de compartición de la meta
      await _supabase
          .from('metas')
          .update({
            'is_shared': false,
            'shared_with_email': null,
            'shared_id': null,
            'estado_invitacion': 'none',
            'shared_permission': 'view',
          })
          .eq('id', goal.id);

      // Si el que abandona es el invitado, enviamos notificación al dueño simulando la estructura clásica
      // (Se delega a FinanceService o una inserción a una tabla de notificaciones si existe,
      // pero provisionalmente se envía un log/registro en consola de Supabase u otra tabla dependiente
      // o se emitirá a posteriori).
      if (isGuest) {
        // En este punto, podríamos insertar en una tabla de 'notifications', ej:
        // await _supabase.from('notifications').insert({...});
      }
    } catch (e) {
      throw Exception('Error al desvincular meta: $e');
    }
  }
}
