import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/transactions_repository.dart';
import '../../models/transaction_model.dart';
import '../widgets/transaction_form_sheet.dart';
import '../../../../core/network/supabase_client.dart';

final recurringTransactionsProvider = FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final repository = TransactionsRepository(supabase: supabaseClient);
  return repository.getRecurringTransactions();
});

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recurringAsync = ref.watch(recurringTransactionsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Transacciones Recurrentes',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: recurringAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.repeat_rounded, size: 64, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   Text(
                    'No tienes reglas recurrentes',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega pagos fijos como sueldos o suscripciones',
                    style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return ListView.separated(
            padding: const EdgeInsets.all(AppColors.md),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _RecurringTransactionCard(transaction: tx, isDark: isDark, ref: ref);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTransactionFormSheet(context, isRecurringDefault: true)
            .then((_) => ref.refresh(recurringTransactionsProvider)),
        label: Text(
          'Nueva Regla',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _RecurringTransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final bool isDark;
  final WidgetRef ref;

  const _RecurringTransactionCard({
    required this.transaction,
    required this.isDark,
    required this.ref,
  });

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(amount);
  }

  String _getFrequencyLabel(String? rule) {
    if (rule == null) return 'Desconocido';
    if (rule.startsWith('monthly_day_')) {
      final day = rule.split('_').last;
      return 'Mensual (día $day)';
    }
    switch (rule) {
      case 'quincenal': return 'Quincenal (15 y último)';
      case 'monthly_last_day': return 'Último día del mes';
      case 'monthly_last_friday': return 'Mensual (último viernes)';
      case 'biweekly': return 'Cada 2 semanas';
      case 'weekly': return 'Cada semana';
      case 'bimonthly': return 'Cada 2 meses';
      default: return 'Recurrente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = transaction.tipo == 'ingreso' ? Colors.green : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.repeat_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.descripcion ?? 'Sin descripción',
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  _getFrequencyLabel(transaction.recurringRule),
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodySmall,
                    color: Colors.grey,
                  ),
                ),
                if (transaction.nextOccurrence != null)
                  Text(
                    'Próx: ${DateFormat('d MMM yyyy', 'es').format(transaction.nextOccurrence!)}',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodySmall,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(transaction.monto),
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.bodyLarge,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                    onPressed: () => showTransactionFormSheet(context, transaction: transaction)
                        .then((_) => ref.refresh(recurringTransactionsProvider)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red[300]),
                    onPressed: () async {
                      // Confirmar eliminación
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Eliminar regla'),
                          content: const Text('¿Estás seguro de eliminar esta regla recurrente?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      
                      if (confirm == true) {
                        try {
                          await TransactionsRepository(supabase: supabaseClient).deleteTransaction(transaction.id);
                          ref.invalidate(recurringTransactionsProvider);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
