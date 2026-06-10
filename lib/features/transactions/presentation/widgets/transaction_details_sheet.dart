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
    useRootNavigator: true,
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
      
      // Compatibilidad v1
      'tag_outline': Icons.label_outline,
      'restaurant_outline': Icons.restaurant_outlined,
      'cart_outline': Icons.shopping_cart_outlined,
      'car_sport_outline': Icons.directions_car_outlined,
      'home_outline': Icons.home_outlined,
      'shirt_outline': Icons.checkroom_outlined,
      'game_controller_outline': Icons.sports_esports_outlined,
      'fitness_outline': Icons.fitness_center_outlined,
      'airplane_outline': Icons.flight_outlined,
      'medical_outline': Icons.medical_services_outlined,
      'school_outline': Icons.school_outlined,
      'briefcase_outline': Icons.work_outline,
      'pricetags_outline': Icons.label_outline,
      'wallet_outline': Icons.account_balance_wallet_outlined,
      'cash_outline': Icons.payments_outlined,
      'card_outline': Icons.credit_card_outlined,
      'trending_up_outline': Icons.trending_up,
      'gift_outline': Icons.card_giftcard_outlined,
      'beer_outline': Icons.sports_bar_outlined,
      'fast_food_outline': Icons.fastfood_outlined,
      'book_outline': Icons.book_outlined,
      'cut_outline': Icons.content_cut_outlined,
      'paw_outline': Icons.pets_outlined,
      'flower_outline': Icons.local_florist_outlined,
      'football_outline': Icons.sports_soccer_outlined,
      'umbrella_outline': Icons.umbrella_outlined,
      'water_outline': Icons.water_drop_outlined,
      'bus_outline': Icons.directions_bus_outlined,
      'bicycle_outline': Icons.directions_bike_outlined,
      'train_outline': Icons.train_outlined,
      'camera_outline': Icons.photo_camera_outlined,
      'musical_notes_outline': Icons.music_note_outlined,
      'film_outline': Icons.movie_outlined,
      'cafe_outline': Icons.local_cafe_outlined,
      'pizza_outline': Icons.local_pizza_outlined,
      'ice_cream_outline': Icons.icecream_outlined,
      'phone_portrait_outline': Icons.smartphone_outlined,
      'bulb_outline': Icons.lightbulb_outline,
      'wifi': Icons.wifi,
      'network_wifi': Icons.network_wifi,
      'commute': Icons.commute,
      'local_taxi': Icons.local_taxi,
      'subway': Icons.subway,
      'house': Icons.house,
      'apartment': Icons.apartment,
      'cottage': Icons.cottage,
      'cleaning_services': Icons.cleaning_services,
      'local_gas_station': Icons.local_gas_station,
      'celebration': Icons.celebration,
      'event': Icons.event,
      'theater_comedy': Icons.theater_comedy,
      'local_pharmacy': Icons.local_pharmacy,
      'medication': Icons.medication,
      'receipt_long': Icons.receipt_long,
      'savings': Icons.savings,
      'build': Icons.build,
      'brush': Icons.brush,
      'camera_alt': Icons.camera_alt,
      'videogame_asset': Icons.videogame_asset,
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
                        minimumSize: const Size(double.infinity, AppColors.interactiveHeight),
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
                        minimumSize: const Size(double.infinity, AppColors.interactiveHeight),
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
                      minimumSize: const Size(double.infinity, AppColors.interactiveHeight),
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
