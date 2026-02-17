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
      final category = categoriesAsync.asData?.value
          .where((c) => c.id == transaction.categoriaId)
          .firstOrNull;
      if (category != null) {
        displayCategoryName = category.nombre;
        displayCategoryIcon = _getMaterialIconData(category.icono);
        displayCategoryColor = _parseHexColor(category.color);
      }
    }

    // Resolver info de cuenta si no se pasó
    AccountModel? account;
    account = accountsAsync.asData?.value
        .where((a) => a.id == transaction.cuentaOrigenId)
        .firstOrNull;
    if (account != null) {
      displayAccountName = account.nombre;
    }

    // Resolver símbolo de moneda
    String displayCurrencySymbol = currencySymbol;
    if (account != null) {
      final currencyAsync = ref.watch(currencyByIdProvider(account.monedaId));
      displayCurrencySymbol =
          currencyAsync.asData?.value?.simbolo ?? currencySymbol;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surface;
    final isCompleted = transaction.estado == 'completa';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppColors.pagePadding,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        border: Border.all(
          color: isCompleted 
            ? Colors.transparent 
            : (isDark ? Colors.orange.withOpacity(0.3) : Colors.orange.withOpacity(0.1)),
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        child: InkWell(
          onTap: onEdit,
          onLongPress: onDelete,
          child: Padding(
            padding: const EdgeInsets.all(AppColors.cardPadding),
            child: Column(
              children: [
                // Fila Superior: Icono, Categoría/Desc y Monto
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Icono de Categoría
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: displayCategoryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
                      ),
                      child: Icon(
                        displayCategoryIcon,
                        color: displayCategoryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Información Central (Categoría y Descripción)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. Nombre de la categoría
                          Text(
                            displayCategoryName ?? transaction.tipo.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // 3. Descripción
                          if (transaction.descripcion != null && transaction.descripcion!.isNotEmpty)
                            Text(
                              transaction.descripcion!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                color: isDark ? Colors.white60 : AppColors.textPrimary.withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // 6. Monto (Alineado arriba a la derecha)
                    Text(
                      _formatCurrency(transaction.monto, displayCurrencySymbol),
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: _getAmountColor(),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Línea divisoria sutil
                Divider(
                  height: 1, 
                  color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
                ),
                
                const SizedBox(height: 12),

                // Fila Inferior: Banco, Fecha y Controles
                Row(
                  children: [
                    // Columna de Metadatos (Banco y Fecha)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 4. Banco
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_rounded,
                                size: 14,
                                color: isDark ? Colors.white70 : Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  displayAccountName ?? 'Cuenta general',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 5. Fecha
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatDate(transaction.fecha),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // 7. Switch y 8. Opciones
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Switch de estado
                        if (!isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'PENDIENTE',
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 28,
                          width: 44,
                          child: Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: isCompleted,
                              activeColor: Colors.white,
                              activeTrackColor: AppColors.primary,
                              inactiveThumbColor: Colors.grey[400],
                              inactiveTrackColor: Colors.grey[200],
                              onChanged: (value) async {
                                final updatedTx = transaction.copyWith(
                                  estado: value ? 'completa' : 'pendiente',
                                );
                                if (value) {
                                  await ref.read(transactionsNotifierProvider.notifier).markAsComplete(transaction);
                                } else {
                                  await ref.read(transactionsNotifierProvider.notifier).markAsPending(transaction);
                                }
                                ref.read(financeServiceProvider).updateAfterTransaction(updatedTx, ref);
                              },
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              size: 20,
                              color: isDark ? Colors.white38 : AppColors.textPrimary.withOpacity(0.3),
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppColors.radiusMedium),
                            ),
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
                                    const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    const SizedBox(width: 8),
                                    Text('Eliminar', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: AppColors.error)),
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

