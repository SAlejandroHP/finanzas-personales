import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _supabase
          .from('deudas')
          .select()
          .eq('user_id', userId)
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

      final debtData = debt.copyWith(
        userId: userId,
        createdAt: DateTime.now(),
      );

      await _supabase.from('deudas').insert(debtData.toJson());
    } catch (e) {
      throw Exception('Error al crear deuda: $e');
    }
  }

  /// Actualiza una deuda existente
  Future<void> updateDebt(DebtModel debt) async {
    try {
      await _supabase
          .from('deudas')
          .update(debt.toJson())
          .eq('id', debt.id);
    } catch (e) {
      throw Exception('Error al actualizar deuda: $e');
    }
  }

  /// Elimina una deuda
  Future<void> deleteDebt(String id) async {
    try {
      await _supabase.from('deudas').delete().eq('id', id);
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
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('deudas')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => DebtModel.fromJson(json)).toList());
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

      await _supabase
          .from('deudas')
          .update({
            'monto_restante': nuevoRestante,
            'updated_at': DateTime.now().toIso8601String(),
            'estado': nuevoRestante <= 0 ? 'pagada' : 'activa'
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Error al actualizar monto de deuda: $e');
    }
  }
}
