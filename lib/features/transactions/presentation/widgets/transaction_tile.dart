import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../accounts/presentation/providers/currencies_provider.dart';
import '../../../accounts/models/account_model.dart';
import '../../../../core/services/finance_service.dart';

/// Widget reutilizable para mostrar una transacción de forma compacta.
/// Muestra ícono por tipo, descripción + fecha, monto coloreado, y botones de edición/eliminación.
/// Corrección v4: Ahora incluye toggle de estado, banco/cuenta y categoría con íconos
class TransactionTile extends ConsumerWidget { // Corrección v4: Cambiado a ConsumerWidget
  final TransactionModel transaction;
  final String? accountName;
  final String? categoryName;
  final String? categoryIcon;
  final Color? categoryColor;
  final String currencySymbol;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TransactionTile({
    Key? key,
    required this.transaction,
    this.accountName,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.currencySymbol = '\$',
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  /// Retorna el ícono correspondiente al tipo de transacción
  /// Retorna el color del ícono según el tipo de transacción
  Color _getIconColor() {
    switch (transaction.tipo) {
      case 'gasto':
        return Colors.red;
      case 'ingreso':
        return Colors.green;
      case 'transferencia':
        return Colors.blue;
      case 'deuda_pago':
        return Colors.orange;
      case 'meta_aporte':
        return Colors.purple;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Retorna el color del monto según el tipo
  Color _getAmountColor() {
    switch (transaction.tipo) {
      case 'gasto':
        return Colors.red;
      case 'ingreso':
        return Colors.green;
      default:
        return AppColors.textPrimary;
    }
  }

  /// Retorna el signo del monto
  String _getAmountSign() {
    switch (transaction.tipo) {
      case 'gasto':
        return '-';
      case 'ingreso':
        return '+';
      default:
        return '';
    }
  }

  /// Formatea el monto como moneda según la cuenta
  String _formatCurrency(double amount, String symbol) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
      locale: 'en_US', // Para asegurar formato 1,000.00
    );
    return '${_getAmountSign()}${formatter.format(amount)}';
  }

  /// Formatea la fecha
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final ayer = hoy.subtract(const Duration(days: 1));
    final fechaTransaction = DateTime(date.year, date.month, date.day);

    String dayLabel;
    if (fechaTransaction == hoy) {
      dayLabel = 'Hoy';
    } else if (fechaTransaction == ayer) {
      dayLabel = 'Ayer';
    } else {
      dayLabel = DateFormat('EEEE d', 'es').format(date);
    }

    final restOfDate = DateFormat('MMM yyyy', 'es').format(date);
    final capitalizedDay = dayLabel.isNotEmpty 
        ? '${dayLabel[0].toUpperCase()}${dayLabel.substring(1)}' 
        : dayLabel;
    
    return '$capitalizedDay · $restOfDate';
  }

  /// Obtiene el ícono de Material desde string
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

  /// Parsea color hex a Color
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
    final categoriesAsync = ref.watch(categoriesListProvider);
    final accountsAsync = ref.watch(accountsListProvider);

    String? displayCategoryName = categoryName;
    IconData displayCategoryIcon = _getMaterialIconData(categoryIcon);
    Color displayCategoryColor = categoryColor ?? _getIconColor();

    String? displayAccountName = accountName;

    // Resolver info de categoría si no se pasó
    if (displayCategoryName == null && transaction.categoriaId != null) {
      final category = categoriesAsync.asData?.value.where((c) => c.id == transaction.categoriaId).firstOrNull;
      if (category != null) {
        displayCategoryName = category.nombre;
        displayCategoryIcon = _getMaterialIconData(category.icono);
        displayCategoryColor = _parseHexColor(category.color);
      }
    }

    // Resolver info de cuenta si no se pasó
    AccountModel? account;
    if (displayAccountName == null || true) { // Necesitamos la cuenta para la moneda siempre
      account = accountsAsync.asData?.value.where((a) => a.id == transaction.cuentaOrigenId).firstOrNull;
      if (account != null) {
        displayAccountName = account.nombre;
      }
    }

    // Resolver símbolo de moneda
    String displayCurrencySymbol = currencySymbol;
    if (account != null) {
      final currencyAsync = ref.watch(currencyByIdProvider(account.monedaId));
      displayCurrencySymbol = currencyAsync.asData?.value?.simbolo ?? currencySymbol;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surface;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppColors.pagePadding, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        child: InkWell(
          onTap: onEdit,
          onLongPress: onDelete, // Acceso rápido a eliminar
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppColors.contentGap, vertical: 10),
            child: Row(
              children: [
                // Ícono de categoría más compacto
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: displayCategoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    displayCategoryIcon,
                    color: displayCategoryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Información Central
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayCategoryName ?? transaction.tipo.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      if (transaction.descripcion != null && transaction.descripcion!.isNotEmpty)
                        Text(
                          transaction.descripcion!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            color: isDark ? Colors.white54 : AppColors.textPrimary.withOpacity(0.5),
                            fontSize: AppColors.bodySmall,
                          ),
                        ),
                      if (transaction.isRecurring && transaction.nextOccurrence != null && 
                          transaction.nextOccurrence!.difference(DateTime.now()).inDays >= 0 &&
                          transaction.nextOccurrence!.difference(DateTime.now()).inDays <= 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_alarm_rounded, size: 12, color: Colors.orange),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Vence en ${transaction.nextOccurrence!.difference(DateTime.now()).inDays} días${(transaction.descripcion?.toLowerCase().contains('internet') ?? false) ? ' – Paga antes y ahorra \$50' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: AppColors.bodySmall,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined, 
                            size: 10, 
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              displayAccountName ?? 'Cuenta',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                fontSize: AppColors.bodySmall,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time_outlined, 
                            size: 10, 
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatDate(transaction.fecha),
                            style: GoogleFonts.montserrat(
                              fontSize: AppColors.bodySmall,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Lado Derecho: Monto, Switch Delgado y Menú
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCurrency(transaction.monto, displayCurrencySymbol),
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        color: _getAmountColor(),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.7, // Más pequeño como pidió el usuario
                          child: Switch(
                            value: transaction.estado == 'completa',
                            activeTrackColor: AppColors.primary, // Usando Teal de app_colors
                            activeColor: Colors.white,
                            onChanged: (value) async {
                              final updatedTx = transaction.copyWith(
                                estado: value ? 'completa' : 'pendiente',
                              );
                              
                              if (value) {
                                await ref.read(transactionsNotifierProvider.notifier).markAsComplete(transaction);
                              } else {
                                await ref.read(transactionsNotifierProvider.notifier).markAsPending(transaction);
                              }
                              
                              // Llama a FinanceService para refrescar saldos y providers en toda la app
                              ref.read(financeServiceProvider).updateAfterTransaction(updatedTx, ref);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: Colors.transparent,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 20,
                              color: isDark ? Colors.white60 : AppColors.textPrimary.withOpacity(0.4),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'edit') onEdit?.call();
                              if (value == 'delete') onDelete?.call();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Editar', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text('Eliminar', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

