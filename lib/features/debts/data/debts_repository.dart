import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';

/// Repositorio para gestionar las operaciones de deudas en Supabase.
class DebtsRepository {
  final SupabaseClient _supabase;

  DebtsRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? supabaseClient;

  /// Obtiene todas las deudas del usuario actual
  Future<List<DebtModel>> getUserDebts() async {
    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      final email = user?.email?.trim().toLowerCase();
      
      if (userId == null) return [];

      // Buscar deudas donde soy el dueño O soy el invitado y he aceptado
      final response = await _supabase
          .from('deudas')
          .select()
          .or('user_id.eq.$userId,and(shared_with_email.ilike.$email,estado_invitacion.eq.accepted)')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DebtModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener deudas: $e');
    }
  }

  /// Crea una nueva deuda
  Future<void> createDebt(DebtModel debt) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Validar si es una nueva invitación compartida
      String estadoInvitacion = debt.estadoInvitacion;
      String? sharedWithEmail = debt.sharedWithEmail?.trim().toLowerCase();
      if (debt.isShared && (sharedWithEmail?.isNotEmpty ?? false) && estadoInvitacion == 'none') {
        estadoInvitacion = 'pending';
      }

      final debtData = debt.copyWith(
        userId: userId,
        createdAt: DateTime.now(),
        estadoInvitacion: estadoInvitacion,
        sharedWithEmail: sharedWithEmail,
      );

      await _supabase.from('deudas').insert(debtData.toJson());
    } catch (e) {
      throw Exception('Error al crear deuda: $e');
    }
  }

  /// Actualiza una deuda existente
  Future<void> updateDebt(DebtModel debt) async {
    try {
      // Validar si se está activando la compartición ahora
      String estadoInvitacion = debt.estadoInvitacion;
      String? sharedWithEmail = debt.sharedWithEmail?.trim().toLowerCase();
      if (debt.isShared && (sharedWithEmail?.isNotEmpty ?? false) && estadoInvitacion == 'none') {
        estadoInvitacion = 'pending';
      }

      final updateData = debt.copyWith(
        estadoInvitacion: estadoInvitacion,
        sharedWithEmail: sharedWithEmail,
      ).toJson()
        ..remove('user_id')
        ..remove('id')
        ..remove('created_at');

      // Si es compartida y ya está aceptada, actualizamos por shared_id para que afecte a ambos registros
      if (debt.isShared && debt.sharedId != null && estadoInvitacion == 'accepted') {
        await _supabase
            .from('deudas')
            .update(updateData)
            .eq('shared_id', debt.sharedId!);
      } else {
        // Si es nueva invitación o privada, solo actualizamos el registro local
        await _supabase
            .from('deudas')
            .update(updateData)
            .eq('id', debt.id);
      }
    } catch (e) {
      throw Exception('Error al actualizar deuda: $e');
    }
  }

  /// Elimina una deuda
  Future<void> deleteDebt(String id) async {
    try {
      // 1. Verificar si era compartida
      final debtData = await _supabase.from('deudas').select('shared_id').eq('id', id).maybeSingle();
      final sharedId = debtData?['shared_id'];

      // 2. Eliminarla localmente
      await _supabase.from('deudas').delete().eq('id', id);

      // 3. Si era compartida, desvincularla de la contraparte para que no reaparezca
      if (sharedId != null) {
        await _supabase.from('deudas').update({
          'is_shared': false,
          'shared_with_email': null,
          'shared_id': null,
          'estado_invitacion': 'none',
        }).eq('shared_id', sharedId);
      }
    } catch (e) {
      throw Exception('Error al eliminar deuda: $e');
    }
  }

  /// Obtiene una deuda específica por ID
  Future<DebtModel?> getDebtById(String id) async {
    try {
      final response = await _supabase
          .from('deudas')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return DebtModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Stream de cambios en tiempo real
  Stream<List<DebtModel>> get debtsStream {
    final user = _supabase.auth.currentUser;
    final userId = user?.id;
    final email = user?.email?.trim().toLowerCase();
    
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('deudas')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data
            .where((json) {
              final ownerId = json['user_id'] as String?;
              final invitedEmail = (json['shared_with_email'] as String?)?.toLowerCase();
              final status = json['estado_invitacion'] as String?;
              
              return ownerId == userId || (invitedEmail == email && status == 'accepted');
            })
            .map((json) => DebtModel.fromJson(json))
            .toList());
  }

  /// Actualiza el monto restante de una deuda (incrementa o decrementa)
  /// isPayment = true -> resta al restante
  /// isPayment = false -> suma al restante (nuevo consumo)
  Future<void> updateDebtAmount(String id, double amount, {required bool isPayment}) async {
    try {
      final debt = await getDebtById(id);
      if (debt == null) throw Exception('Deuda no encontrada');

      double nuevoRestante = isPayment 
          ? debt.montoRestante - amount 
          : debt.montoRestante + amount;

      if (nuevoRestante < 0) nuevoRestante = 0;

      final updateData = {
        'monto_restante': nuevoRestante,
        'estado': nuevoRestante <= 0 ? 'pagada' : 'activa'
      };

      if (debt.isShared && debt.sharedId != null) {
        await _supabase
            .from('deudas')
            .update(updateData)
            .eq('shared_id', debt.sharedId!);
      } else {
        await _supabase
            .from('deudas')
            .update(updateData)
            .eq('id', id);
      }
    } catch (e) {
      throw Exception('Error al actualizar monto de deuda: $e');
    }
  }
  /// Obtiene deudas compartidas invitadas al email del usuario pero no aceptadas aún
  Future<List<DebtModel>> getPendingInvitations() async {
    try {
      final user = _supabase.auth.currentUser;
      final email = user?.email?.trim().toLowerCase();
      final userId = user?.id;
      
      if (email == null || userId == null) return [];


      // 1. Obtener deudas donde soy el invitado y están pendientes

      // 1. Obtener deudas donde soy el invitado y están pendientes
      // IMPORTANTE: Asegurarse de que el RLS permita ver estas filas aunque no seas el user_id
      final invitedResponse = await _supabase
          .from('deudas')
          .select()
          .ilike('shared_with_email', email)
          .eq('estado_invitacion', 'pending');

      final result = (invitedResponse as List)
          .map((json) => DebtModel.fromJson(json))
          .toList();


      return result;
    } catch (e) {
      return [];
    }
  }

  /// Stream de invitaciones pendientes para notificaciones en tiempo real
  Stream<List<DebtModel>> get pendingInvitationsStream {
    final user = _supabase.auth.currentUser;
    final email = user?.email?.trim().toLowerCase();
    
    if (email == null) return Stream.value([]);

    return _supabase
        .from('deudas')
        .stream(primaryKey: ['id'])
        .eq('estado_invitacion', 'pending')
        .map((data) => data
            .where((json) => (json['shared_with_email'] as String?)?.toLowerCase() == email)
            .map((json) => DebtModel.fromJson(json))
            .toList());
  }

  /// Acepta una invitación creando un registro espejo para el usuario actual
  Future<void> acceptInvitation(DebtModel invitation) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // En el modelo de REGISTRO ÚNICO, solo actualizamos el estado en la deuda original.
      // Ya no creamos un registro espejo.
      await _supabase.from('deudas').update({
        'estado_invitacion': 'accepted',
      }).eq('id', invitation.id);


    } catch (e) {
      throw Exception('Error al aceptar invitación: $e');
    }
  }

  /// Desvincula una deuda compartida (deja de sincronizar pero mantiene el registro)
  Future<void> unlinkDebt(String id) async {
    try {
      // En el registro único, desvincular significa limpiar los campos de compartición
      // para que el invitado pierda el acceso (ya no aparecerá en su query).
      await _supabase.from('deudas').update({
        'is_shared': false,
        'shared_with_email': null,
        'shared_id': null,
        'estado_invitacion': 'none',
      }).eq('id', id);


    } catch (e) {
      throw Exception('Error al desvincular deuda: $e');
    }
  }

  /// Rechaza una invitación indicándolo en el registro original
  Future<void> rejectInvitation(DebtModel invitation) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Modificamos el registro original estableciendo 'rejected'
      await _supabase.from('deudas').update({
        'estado_invitacion': 'rejected',
      }).eq('id', invitation.id);
    } catch (e) {
      throw Exception('Error al rechazar invitación: $e');
    }
  }

  /// Obtiene los IDs de todas las deudas vinculadas a un shared_id
  Future<List<Map<String, String>>> getRelatedSharedDebts(String sharedId) async {
    try {
      final response = await _supabase
          .from('deudas')
          .select('id, user_id')
          .eq('shared_id', sharedId);
      
      return (response as List).map((row) => {
        'id': row['id'] as String,
        'user_id': row['user_id'] as String,
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
