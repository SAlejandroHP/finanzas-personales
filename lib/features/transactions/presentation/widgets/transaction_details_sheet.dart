import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../accounts/presentation/providers/currencies_provider.dart';
import 'transaction_form_sheet.dart';

void showTransactionDetailsSheet(BuildContext context, {required TransactionModel transaction}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TransactionDetailsSheet(transaction: transaction),
  );
}

class TransactionDetailsSheet extends ConsumerWidget {
  final TransactionModel transaction;

  const TransactionDetailsSheet({
    Key? key,
    required this.transaction,
  }) : super(key: key);

  Color _getIconColor() {
    switch (transaction.tipo) {
      case 'gasto': return Colors.red;
      case 'ingreso': return Colors.green;
      case 'transferencia': return Colors.blue;
      case 'pago_deuda': return Colors.orange;
      case 'meta_aporte': return Colors.purple;
      default: return AppColors.textSecondary;
    }
  }

  Color _getAmountColor() {
    switch (transaction.tipo) {
      case 'gasto': return Colors.red;
      case 'ingreso': return Colors.green;
      default: return AppColors.textPrimary;
    }
  }

  String _getAmountSign() {
    switch (transaction.tipo) {
      case 'gasto': return '-';
      case 'ingreso': return '+';
      default: return '';
    }
  }

  IconData _getMaterialIconData(String? iconName) {
    if (iconName == null || iconName.isEmpty) return Icons.label_outline;
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
      'fastfood_outlined': Icons.fastfood_outlined,
      // Se pueden agregar más según _getMaterialIconData en TransactionTile
    };
    return iconMap[iconName] ?? Icons.label_outline;
  }

  Color _parseHexColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return AppColors.primary;
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoriesListProvider);
    final accountsAsync = ref.watch(accountsListProvider);

    String displayCategoryName = transaction.tipo.toUpperCase();
    IconData displayCategoryIcon = Icons.label_outline;
    Color displayCategoryColor = _getIconColor();

    if (transaction.categoriaId != null) {
      final category = categoriesAsync.asData?.value
          .where((c) => c.id == transaction.categoriaId)
          .firstOrNull;
      if (category != null) {
        displayCategoryName = category.nombre;
        displayCategoryIcon = _getMaterialIconData(category.icono);
        displayCategoryColor = _parseHexColor(category.color);
      }
    }

    String displayAccountName = 'Cuenta General';
    String currencySymbol = '\$';
    
    final account = accountsAsync.asData?.value
        .where((a) => a.id == transaction.cuentaOrigenId)
        .firstOrNull;
    
    if (account != null) {
      displayAccountName = account.nombre;
      final currencyAsync = ref.watch(currencyByIdProvider(account.monedaId));
      currencySymbol = currencyAsync.asData?.value?.simbolo ?? '\$';
    }

    final formatter = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2, locale: 'en_US');
    final formattedAmount = '${_getAmountSign()}${formatter.format(transaction.monto)}';
    final formattedDate = DateFormat('EEEE d \'de\' MMMM, yyyy', 'es').format(transaction.fecha);
    
    final isCompleted = transaction.estado == 'completa' || transaction.estado == 'pagada';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grabber
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Categoría Icono
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: displayCategoryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  displayCategoryIcon,
                  color: displayCategoryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              
              // Monto
              Text(
                formattedAmount,
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: _getAmountColor(),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              
              // Categoría Nombre
              Text(
                displayCategoryName,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              
              if (transaction.descripcion != null && transaction.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  transaction.descripcion!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Detalles (Lista)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Fecha', formattedDate, Icons.calendar_today_rounded, isDark),
                    const Divider(height: 24),
                    _buildDetailRow('Cuenta', displayAccountName, Icons.account_balance_rounded, isDark),
                    const Divider(height: 24),
                    _buildDetailRow('Estado', isCompleted ? 'Completado' : 'Pendiente', 
                      isCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded, 
                      isDark,
                      valueColor: isCompleted ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Cerrar sheet actual
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar transacción'),
                            content: const Text('¿Estás seguro de que deseas eliminarla?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await ref.read(transactionsNotifierProvider.notifier).deleteTransaction(transaction.id);
                                  if (context.mounted) showAppToast(context, message: 'Eliminada', type: ToastType.success);
                                },
                                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showTransactionFormSheet(context, transaction: transaction);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isCompleted) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(transactionsNotifierProvider.notifier).markAsComplete(transaction);
                      Navigator.pop(context);
                      showAppToast(context, message: 'Marcado como PAGADO', type: ToastType.success);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marcar como Pagado'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white54 : Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white70 : Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : AppColors.textPrimary),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
