import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../accounts/presentation/providers/currencies_provider.dart';
import '../../../accounts/models/account_model.dart';
import 'transaction_details_sheet.dart';

/// Widget reutilizable para mostrar una transacción de forma compacta.
/// Muestra ícono por tipo, descripción + fecha, monto coloreado, y botones de edición/eliminación.
/// Corrección v4: Ahora incluye toggle de estado, banco/cuenta y categoría con íconos
class TransactionTile extends ConsumerWidget {
  final TransactionModel transaction;
  final String? accountName;
  final String? categoryName;
  final String? categoryIcon;
  final Color? categoryColor;
  final String currencySymbol;

  const TransactionTile({
    Key? key,
    required this.transaction,
    this.accountName,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.currencySymbol = '\$',
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
      case 'pago_deuda':
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

  /// Retorna el nombre legible del tipo de transacción
  String _getTipoFormatted(String tipo) {
    switch (tipo) {
      case 'pago_deuda':
        return 'Pago de deuda';
      case 'meta_aporte':
        return 'Aporte a meta';
      case 'gasto':
        return 'Gasto';
      case 'ingreso':
        return 'Ingreso';
      case 'transferencia':
        return 'Transferencia';
      default:
        return tipo.toUpperCase();
    }
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showTransactionDetailsSheet(context, transaction: transaction);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Icono de Categoría (Círculo)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: displayCategoryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                displayCategoryIcon,
                color: displayCategoryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            
            // 2. Información Central (Categoría, Cuenta, Descripción)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayCategoryName ?? _getTipoFormatted(transaction.tipo),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_rounded,
                        size: 11,
                        color: isDark ? Colors.white54 : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${displayAccountName ?? "Cuenta general"}${transaction.descripcion?.isNotEmpty == true ? " • ${transaction.descripcion}" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.montserrat(
                            color: isDark ? Colors.white60 : Colors.grey[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // 3. Monto y Estado
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatCurrency(transaction.monto, displayCurrencySymbol),
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: _getAmountColor(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                _TransactionStatusButton(
                  transaction: transaction,
                  isDark: isDark,
                  isCompleted: isCompleted,
                ),
              ],
            ),
            
            const SizedBox(width: 12),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
class _TransactionStatusButton extends ConsumerStatefulWidget {
  final TransactionModel transaction;
  final bool isDark;
  final bool isCompleted;

  const _TransactionStatusButton({
    Key? key,
    required this.transaction,
    required this.isDark,
    required this.isCompleted,
  }) : super(key: key);

  @override
  ConsumerState<_TransactionStatusButton> createState() => _TransactionStatusButtonState();
}

class _TransactionStatusButtonState extends ConsumerState<_TransactionStatusButton> {
  bool? _optimisticIsCompleted;

  @override
  void didUpdateWidget(covariant _TransactionStatusButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompleted != widget.isCompleted) {
      _optimisticIsCompleted = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _optimisticIsCompleted ?? widget.isCompleted;

    final fgColor = isCompleted 
        ? (widget.isDark ? Colors.greenAccent : Colors.green[800]) 
        : (widget.isDark ? Colors.orange[300] : Colors.orange[900]);
        
    final bgColor = isCompleted
        ? (widget.isDark ? Colors.greenAccent.withValues(alpha: 0.15) : Colors.green[100])
        : (widget.isDark ? Colors.orange[300]!.withValues(alpha: 0.15) : Colors.orange[100]);

    return SizedBox(
      height: 22,
      child: TextButton.icon(
        onPressed: () async {
          // Actualización optimista inmediata
          setState(() {
            _optimisticIsCompleted = !isCompleted;
          });

          // Pequeño retardo visual para que el usuario alcance a ver
          // que el botón cambió a verde/naranja antes de que la lista se reorganice
          await Future.delayed(const Duration(milliseconds: 700));

          // Operación en segundo plano (silenciosa)
          if (!isCompleted) {
            ref.read(transactionsNotifierProvider.notifier).markAsComplete(widget.transaction);
            if (mounted) showAppToast(context, message: 'Marcado como PAGADO', type: ToastType.success);
          } else {
            ref.read(transactionsNotifierProvider.notifier).markAsPending(widget.transaction);
            if (mounted) showAppToast(context, message: 'Marcado como PENDIENTE', type: ToastType.warning);
          }
        },
        icon: Icon(
          isCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded,
          size: 11,
        ),
        label: Text(
          isCompleted ? 'Pagado' : 'Pendiente',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11), // Forma de píldora
          ),
        ),
      ),
    );
  }
}
