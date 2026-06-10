import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/transaction_filters_provider.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';

class TransactionFiltersSheet extends ConsumerWidget {
  const TransactionFiltersSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(transactionFiltersProvider);
    final accountsAsync = ref.watch(accountsListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtros',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              if (_hasAnyFilter(filters))
                TextButton(
                  onPressed: () {
                    ref.read(transactionFiltersProvider.notifier).state = TransactionFilters();
                    Navigator.pop(context);
                  },
                  child: Text('Limpiar Todo', style: GoogleFonts.montserrat(color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilterRow(
            context: context,
            icon: Icons.filter_alt_outlined,
            label: 'Estatus',
            value: _getStatusLabel(filters.status),
            onTap: () => _showStatusPicker(context, ref),
            isDark: isDark,
          ),
          _buildFilterRow(
            context: context,
            icon: Icons.account_balance_wallet_outlined,
            label: 'Cuenta',
            value: _getAccountName(filters.accountId, accountsAsync),
            onTap: () => _showAccountPicker(context, ref, accountsAsync),
            isDark: isDark,
          ),
          _buildFilterRow(
            context: context,
            icon: Icons.category_outlined,
            label: 'Categoría',
            value: _getCategoryName(filters.categoryId, categoriesAsync),
            onTap: () => _showCategoryPicker(context, ref, categoriesAsync),
            isDark: isDark,
          ),
          _buildFilterRow(
            context: context,
            icon: Icons.payments_outlined,
            label: 'Monto',
            value: _getAmountLabel(filters),
            onTap: () => _showAmountFilter(context, ref),
            isDark: isDark,
          ),
          _buildFilterRow(
            context: context,
            icon: Icons.event_outlined,
            label: 'Fecha',
            value: _getDateLabel(filters),
            onTap: () => _showDatePicker(context, ref),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.montserrat(
              color: value != label && value != 'Monto' && value != 'Fecha' && value != 'Estatus' && value != 'Cuenta' && value != 'Categoría' ? AppColors.primary : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.withOpacity(0.5)),
        ],
      ),
      onTap: onTap,
    );
  }

  bool _hasAnyFilter(TransactionFilters filters) {
    return filters.status != null ||
        filters.accountId != null ||
        filters.categoryId != null ||
        filters.minAmount != null ||
        filters.maxAmount != null ||
        filters.dateRange != null;
  }

  String _getStatusLabel(String? status) {
    if (status == null) return 'Estatus';
    return status == 'completa' ? 'Completa' : 'Pendiente';
  }

  String _getAccountName(String? id, AsyncValue<List<dynamic>> accountsAsync) {
    if (id == null) return 'Cuenta';
    return accountsAsync.maybeWhen(
      data: (accounts) => accounts.where((a) => a.id == id).firstOrNull?.nombre ?? 'Cuenta',
      orElse: () => 'Cuenta',
    );
  }

  String _getCategoryName(String? id, AsyncValue<List<dynamic>> categoriesAsync) {
    if (id == null) return 'Categoría';
    return categoriesAsync.maybeWhen(
      data: (categories) => categories.where((c) => c.id == id).firstOrNull?.nombre ?? 'Categoría',
      orElse: () => 'Categoría',
    );
  }

  String _getAmountLabel(TransactionFilters filters) {
    if (filters.minAmount != null && filters.maxAmount != null) {
      return '\$${filters.minAmount} - \$${filters.maxAmount}';
    } else if (filters.minAmount != null) {
      return '> \$${filters.minAmount}';
    } else if (filters.maxAmount != null) {
      return '< \$${filters.maxAmount}';
    }
    return 'Monto';
  }

  String _getDateLabel(TransactionFilters filters) {
    if (filters.dateRange == null) return 'Fecha';
    final start = filters.dateRange!.start;
    final end = filters.dateRange!.end;
    if (start.day == end.day && start.month == end.month && start.year == end.year) {
      return 'Hoy';
    }
    return '${start.day}/${start.month} - ${end.day}/${end.month}';
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
    useRootNavigator: true,
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Filtrar por estatus',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: AppColors.titleSmall),
              ),
            ),
            ListTile(
              title: Text('Cualquiera', style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium)),
              onTap: () {
                ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(status: null));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Completa', style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium)),
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              onTap: () {
                ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(status: 'completa'));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Pendiente', style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium)),
              leading: const Icon(Icons.access_time_outlined, color: Colors.orange),
              onTap: () {
                ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(status: 'pendiente'));
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountPicker(BuildContext context, WidgetRef ref, AsyncValue<List<dynamic>> accountsAsync) {
    accountsAsync.whenData((accounts) {
      showModalBottomSheet(
    useRootNavigator: true,
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Filtrar por cuenta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppColors.titleSmall)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Todas las cuentas'),
                      onTap: () {
                        ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(accountId: null));
                        Navigator.pop(context);
                      },
                    ),
                    ...accounts.map((a) => ListTile(
                      title: Text(a.nombre),
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      onTap: () {
                        ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(accountId: a.id));
                        Navigator.pop(context);
                      },
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref, AsyncValue<List<dynamic>> categoriesAsync) {
    categoriesAsync.whenData((categories) {
      showModalBottomSheet(
    useRootNavigator: true,
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Filtrar por categoría', style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppColors.titleSmall)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      title: const Text('Todas las categorías'),
                      onTap: () {
                        ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(categoryId: null));
                        Navigator.pop(context);
                      },
                    ),
                    ...categories.map((c) => ListTile(
                      title: Text(c.nombre, style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium)),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _parseHexColor(c.color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getMaterialIconData(c.icono), 
                          color: _parseHexColor(c.color),
                          size: 20,
                        ),
                      ),
                      onTap: () {
                        ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(categoryId: c.id));
                        Navigator.pop(context);
                      },
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showAmountFilter(BuildContext context, WidgetRef ref) {
    final minController = TextEditingController(text: ref.read(transactionFiltersProvider).minAmount?.toString() ?? '');
    final maxController = TextEditingController(text: ref.read(transactionFiltersProvider).maxAmount?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por monto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              decoration: const InputDecoration(labelText: 'Monto mínimo'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppColors.md),
            TextField(
              controller: maxController,
              decoration: const InputDecoration(labelText: 'Monto máximo'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(minAmount: null, maxAmount: null));
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
          ElevatedButton(
            onPressed: () {
              final min = double.tryParse(minController.text);
              final max = double.tryParse(maxController.text);
              ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(minAmount: min, maxAmount: max));
              Navigator.pop(context);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context, WidgetRef ref) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: ref.read(transactionFiltersProvider).dateRange != null 
        ? ref.read(transactionFiltersProvider).dateRange
        : null,
    );

    if (picked != null) {
      ref.read(transactionFiltersProvider.notifier).update((s) => s.copyWith(
        dateRange: picked
      ));
    }
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
    };
    
    return iconMap[iconName] ?? Icons.label_outline;
  }
}
