import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/transaction_model.dart';
import './transactions_provider.dart';

/// Modelo para un aviso de recurrencia
class RecurringWarning {
  final String title;
  final String message;
  final TransactionModel transaction;
  final WarningType type;

  RecurringWarning({
    required this.title,
    required this.message,
    required this.transaction,
    required this.type,
  });
}

enum WarningType { aparta, vence }

/// Provider que calcula avisos basados en transacciones recurrentes y recibo de sueldo
final recurringWarningsProvider = Provider<List<RecurringWarning>>((ref) {
  final transactionsAsync = ref.watch(transactionsListProvider);
  
  return transactionsAsync.maybeWhen(
    data: (transactions) {
      final now = DateTime.now();
      final warnings = <RecurringWarning>[];
      
      // 1. Detectar si hubo ingresos de "Sueldo" o "Quincena" este mes
      final hasSalaryThisMonth = transactions.any((t) => 
        t.tipo == 'ingreso' && 
        t.estado == 'completa' &&
        t.fecha.month == now.month &&
        t.fecha.year == now.year &&
        (t.descripcion?.toLowerCase().contains('sueldo') ?? false) || 
         (t.descripcion?.toLowerCase().contains('quincena') ?? false)
      );

      // 2. Obtener reglas recurrentes
      final rules = transactions.where((t) => t.isRecurring).toList();

      for (final rule in rules) {
        if (rule.nextOccurrence == null) continue;

        final diff = rule.nextOccurrence!.difference(now).inDays;
        
        // Aviso de proximidad (3 días antes)
        if (diff >= 0 && diff <= 3) {
          warnings.add(RecurringWarning(
            title: 'Vence pronto',
            message: '${rule.descripcion ?? 'Pago'} vence en $diff días${(rule.descripcion?.toLowerCase().contains('internet') ?? false) ? ' – paga antes y ahorra \$50' : ''}',
            transaction: rule,
            type: WarningType.vence,
          ));
        } 
        // Aviso de "Aparta" si se recibió sueldo
        else if (hasSalaryThisMonth && diff > 3 && diff <= 20) {
          warnings.add(RecurringWarning(
            title: 'Apartado sugerido',
            message: 'Aparta \$${rule.monto.toStringAsFixed(0)} para ${rule.descripcion ?? 'pago'} antes del ${rule.nextOccurrence!.day}${(rule.descripcion?.toLowerCase().contains('internet') ?? false) ? ' y ahorra \$50' : ''}',
            transaction: rule,
            type: WarningType.aparta,
          ));
        }
      }

      return warnings;
    },
    orElse: () => [],
  );
});
