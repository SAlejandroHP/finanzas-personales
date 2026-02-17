import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../widgets/transaction_form_sheet.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/transaction_filters_bar.dart';
import '../providers/transaction_filters_provider.dart';

/// Pantalla que muestra la lista de todas las transacciones del usuario
class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : AppColors.backgroundColor;
    final appBarColor = isDark ? const Color(0xFF121212) : AppColors.backgroundColor;
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Movimientos',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: AppColors.titleMedium,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: false, // Alineación a la izquierda típica de Material 3
        elevation: 0,
        scrolledUnderElevation: 2, // Elevación al hacer scroll
        backgroundColor: appBarColor,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () async {
              final transactions = transactionsAsync.asData?.value;
              if (transactions != null && transactions.isNotEmpty) {
                 await showSearch(
                  context: context,
                  delegate: _TransactionSearchDelegate(transactions, ref),
                );
              }
            },
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            final hasFilters = _hasAnyFilter(ref.watch(transactionFiltersProvider));
            return Column(
              children: [
                const TransactionFiltersBar(),
                _buildSummaryCard(context, ref, isDark),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasFilters ? Icons.search_off_rounded : Icons.receipt_long_rounded,
                            size: 64,
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: AppColors.lg),
                        Text(
                          hasFilters ? 'Sin resultados' : 'Sin transacciones',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: AppColors.titleSmall,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppColors.sm),
                        Text(
                          hasFilters 
                              ? 'Prueba ajustando los filtros' 
                              : 'Comienza a registrar tus movimientos',
                          style: GoogleFonts.montserrat(
                            color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.6),
                            fontSize: AppColors.bodyMedium,
                          ),
                        ),
                        if (hasFilters) ...[
                          const SizedBox(height: AppColors.lg),
                          TextButton.icon(
                            onPressed: () => ref.read(transactionFiltersProvider.notifier).state = TransactionFilters(),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Limpiar filtros'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              const TransactionFiltersBar(),
              _buildSummaryCard(context, ref, isDark),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 120), // Suficiente para que el último registro suba sobre la barra
                  physics: const BouncingScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return TransactionTile(
                      transaction: transaction,
                      currencySymbol: '\$',
                      onEdit: () {
                        showTransactionFormSheet(
                          context,
                          transaction: transaction,
                        );
                      },
                      onDelete: () {
                        _showDeleteDialog(context, ref, transaction.id);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => Column(
          children: [
            const TransactionFiltersBar(),
            _buildSummaryCard(context, ref, isDark),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ],
        ),
        error: (error, stackTrace) => Column(
          children: [
            const TransactionFiltersBar(),
            _buildSummaryCard(context, ref, isDark),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: AppColors.lg),
                    Text(
                      'Error al cargar transacciones',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: AppColors.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: AppColors.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: AppColors.textPrimary.withOpacity(0.6),
                          fontSize: AppColors.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppColors.lg),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(transactionsListProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    // Corrección v5: Eliminar FloatingActionButton (ya está en nav central)
    );
  }

  Widget _buildSummaryCard(BuildContext context, WidgetRef ref, bool isDark) {
    final summary = ref.watch(filteredTransactionsSummaryProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance del Periodo',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodySmall,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormatter.format(summary.total),
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.titleLarge,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    label: 'Ingresos',
                    amount: summary.income,
                    color: Colors.green,
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.2),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    label: 'Gastos',
                    amount: summary.expenses,
                    color: Colors.redAccent,
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    final currencyFormatter = NumberFormat.compactCurrency(symbol: '\$');
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: AppColors.bodySmall,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormatter.format(amount),
          style: GoogleFonts.montserrat(
            fontSize: AppColors.bodyLarge,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
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

  /// Muestra un diálogo de confirmación para eliminar una transacción
  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    String transactionId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar transacción'),
        content: const Text(
          '¿Está seguro que desea eliminar esta transacción? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(transactionsNotifierProvider.notifier)
                    .deleteTransaction(transactionId);
                if (context.mounted) {
                  Navigator.pop(context);
                  showAppToast(
                    context,
                    message: 'Transacción eliminada',
                    type: ToastType.success,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  showAppToast(
                    context,
                    message: 'Error: $e',
                    type: ToastType.error,
                  );
                }
              }
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionSearchDelegate extends SearchDelegate {
  final List<TransactionModel> transactions;
  final WidgetRef ref;

  _TransactionSearchDelegate(this.transactions, this.ref);

  @override
  String get searchFieldLabel => 'Buscar...';

  @override
  TextStyle get searchFieldStyle => GoogleFonts.montserrat(
    fontSize: AppColors.bodyLarge,
  );

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final queryLower = query.toLowerCase();
    
    final results = transactions.where((t) {
      final descMatch = t.descripcion?.toLowerCase().contains(queryLower) ?? false;
      final amountMatch = t.monto.toString().contains(queryLower);
      final typeMatch = t.tipo.toLowerCase().contains(queryLower);
      return descMatch || amountMatch || typeMatch;
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron resultados',
              style: GoogleFonts.montserrat(
                color: Colors.grey,
                fontSize: AppColors.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF121212) : AppColors.backgroundColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 30),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final transaction = results[index];
          return TransactionTile(
            transaction: transaction,
            onEdit: () {
              close(context, null);
              showTransactionFormSheet(context, transaction: transaction);
            },
            onDelete: () {
              // Confirmación simplificada para no duplicar código complejo
               showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar'),
                  content: const Text('¿Eliminar esta transacción?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        close(context, null); // Cerrar búsqueda
                        await ref.read(transactionsNotifierProvider.notifier).deleteTransaction(transaction.id);
                      },
                      child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
