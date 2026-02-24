import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
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
          'Reglas Recurrentes',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
              ),
              onPressed: () => showTransactionFormSheet(context, isRecurringDefault: true)
                  .then((_) => ref.refresh(recurringTransactionsProvider)),
            ),
          ),
        ],
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
            padding: const EdgeInsets.fromLTRB(AppColors.pagePadding, 8, AppColors.pagePadding, 120),
            physics: const BouncingScrollPhysics(),
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
    final color = transaction.tipo == 'ingreso' ? Colors.green : Colors.redAccent;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10), // Squircle homologado
                ),
                child: Icon(
                  Icons.repeat_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.descripcion ?? 'Sin descripción',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getFrequencyLabel(transaction.recurringRule),
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (transaction.nextOccurrence != null)
                    Text(
                      'Próx: ${DateFormat('d MMM', 'es').format(transaction.nextOccurrence!)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 32,
                child: TextButton.icon(
                  onPressed: () async {
                    // Confirmar eliminación
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar regla'),
                        content: const Text('¿Estás seguro de eliminar esta regla recurrente?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      try {
                        await TransactionsRepository(supabase: supabaseClient).deleteTransaction(transaction.id);
                        ref.invalidate(recurringTransactionsProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                  },
                  icon: Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red[300]),
                  label: Text(
                    'Eliminar',
                    style: GoogleFonts.montserrat(
                      fontSize: 11, 
                      fontWeight: FontWeight.w700,
                      color: Colors.red[300],
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              AppButton(
                label: 'Editar Regla',
                icon: Icons.edit_rounded,
                onPressed: () => showTransactionFormSheet(context, transaction: transaction)
                    .then((_) => ref.refresh(recurringTransactionsProvider)),
                variant: 'primary',
                size: 'small',
                height: 32,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
