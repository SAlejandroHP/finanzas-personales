import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/transactions_repository.dart';
import '../../models/transaction_model.dart';
import '../widgets/transaction_form_sheet.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/finance_service.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import 'package:collection/collection.dart';

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
          'T. Recurrentes',
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
                  .then((_) => ref.read(financeServiceProvider).refreshAll()),
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
          
          double monthlyTotal = 0.0;
          for (final tx in transactions) {
            if (tx.tipo == 'gasto' || tx.tipo == 'pago_deuda' || tx.tipo == 'meta_aporte') {
              double multiplier = 0;
              if (tx.recurringRule == 'weekly') multiplier = 4.3333;
              else if (tx.recurringRule == 'biweekly') multiplier = 2.1666;
              else if (tx.recurringRule == 'quincenal') multiplier = 2;
              else if (tx.recurringRule == 'bimonthly') multiplier = 0.5;
              else if (tx.recurringRule?.startsWith('monthly') ?? false) multiplier = 1;
              monthlyTotal += (tx.monto * multiplier);
            }
          }
          final quincenalTotal = monthlyTotal / 2;
          
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(AppColors.pagePadding, 8, AppColors.pagePadding, 16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.recurringTransactions.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL ESTIMADO AL MES',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(monthlyTotal),
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Barra inferior con indicadores (Estilo Dashboard/Cuentas)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildCompactIndicator(
                                'Mensual',
                                NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(monthlyTotal),
                                Colors.white,
                                Icons.calendar_month_rounded,
                              ),
                            ),
                            Container(height: 20, width: 1, color: Colors.white.withOpacity(0.15)),
                            Expanded(
                              child: _buildCompactIndicator(
                                'Quincenal',
                                NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(quincenalTotal),
                                Colors.white.withOpacity(0.8),
                                Icons.event_repeat_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppColors.pagePadding, 0, AppColors.pagePadding, 120),
                  physics: const BouncingScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _RecurringTransactionCard(transaction: tx, isDark: isDark, ref: ref);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildCompactIndicator(String label, String amount, Color color, IconData icon) {
    return Column(
      children: [
        Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(icon, size: 10, color: color.withOpacity(0.8)),
             const SizedBox(width: 4),
             Text(
               label.toUpperCase(),
               style: GoogleFonts.montserrat(
                 fontSize: 8,
                 fontWeight: FontWeight.w800,
                 color: color.withOpacity(0.7),
                 letterSpacing: 0.5,
               ),
             ),
           ],
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
      ],
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

  IconData _getIcon(String? iconName) {
    final iconMap = {
      'label_outline': Icons.label_outline,
      'restaurant_outlined': Icons.restaurant_outlined,
      'shopping_cart_outlined': Icons.shopping_cart_outlined,
      'directions_car_outlined': Icons.directions_car_outlined,
      'home_outlined': Icons.home_outlined,
      'checkroom_outlined': Icons.checkroom_outlined,
      'sports_esports_outlined': Icons.sports_esports_outlined,
      'fitness_center_outlined': Icons.fitness_center_outlined,
      'flight_outlined': Icons.flight_outlined,
      'medical_services_outlined': Icons.medical_services_outlined,
      'school_outlined': Icons.school_outlined,
      'work_outline': Icons.work_outline,
      'account_balance_wallet_outlined': Icons.account_balance_wallet_outlined,
      'payments_outlined': Icons.payments_outlined,
      'credit_card_outlined': Icons.credit_card_outlined,
      'trending_up': Icons.trending_up,
      'card_giftcard_outlined': Icons.card_giftcard_outlined,
      'sports_bar_outlined': Icons.sports_bar_outlined,
      'fastfood_outlined': Icons.fastfood_outlined,
      'book_outlined': Icons.book_outlined,
      'content_cut_outlined': Icons.content_cut_outlined,
      'pets_outlined': Icons.pets_outlined,
      'local_florist_outlined': Icons.local_florist_outlined,
      'sports_soccer_outlined': Icons.sports_soccer_outlined,
      'umbrella_outlined': Icons.umbrella_outlined,
      'water_drop_outlined': Icons.water_drop_outlined,
      'directions_bus_outlined': Icons.directions_bus_outlined,
      'directions_bike_outlined': Icons.directions_bike_outlined,
      'train_outlined': Icons.train_outlined,
      'photo_camera_outlined': Icons.photo_camera_outlined,
      'music_note_outlined': Icons.music_note_outlined,
      'movie_outlined': Icons.movie_outlined,
      'local_cafe_outlined': Icons.local_cafe_outlined,
      'local_pizza_outlined': Icons.local_pizza_outlined,
      'icecream_outlined': Icons.icecream_outlined,
      'laptop_outlined': Icons.laptop_outlined,
      'smartphone_outlined': Icons.smartphone_outlined,
      'headset_outlined': Icons.headset_outlined,
      'lightbulb_outline': Icons.lightbulb_outline,
    };
    return iconMap[iconName] ?? Icons.label_outline;
  }

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.grey;
    try {
      final hexString = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hexString', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);
    
    Color color = transaction.tipo == 'ingreso' ? Colors.green : Colors.redAccent;
    IconData categoryIcon = Icons.repeat_rounded;
    
    categoriesAsync.whenData((categories) {
      if (transaction.categoriaId != null) {
        final cat = categories.firstWhereOrNull((c) => c.id == transaction.categoriaId);
        if (cat != null) {
          color = _getColorFromHex(cat.color);
          categoryIcon = _getIcon(cat.icono);
        }
      }
    });
    
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
                  categoryIcon,
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
              AppButton(
                label: 'Eliminar',
                icon: Icons.delete_outline_rounded,
                variant: 'outlined',
                size: 'small',
                height: 32,
                textColor: AppColors.error,
                onPressed: () async {
                  // Confirmar eliminación
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Eliminar regla'),
                      content: const Text('¿Estás seguro de eliminar esta regla recurrente?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await TransactionsRepository(supabase: supabaseClient).deleteTransaction(transaction.id);
                      ref.read(financeServiceProvider).refreshAll();
                    } catch (e) {
                      if (context.mounted) {
                        showAppToast(context, message: 'Error: $e', type: ToastType.error);
                      }
                    }
                  }
                },
              ),
              AppButton(
                label: 'Editar Regla',
                icon: Icons.edit_rounded,
                onPressed: () => showTransactionFormSheet(context, transaction: transaction)
                    .then((_) => ref.read(financeServiceProvider).refreshAll()),
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
