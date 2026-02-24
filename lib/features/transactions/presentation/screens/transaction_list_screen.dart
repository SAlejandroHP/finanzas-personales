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

// Función de utilidad para formatear la fecha del encabezado
String _formatDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  if (date.year == today.year && date.month == today.month && date.day == today.day) {
    return 'Hoy';
  } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
    return 'Ayer';
  } else if (date.year == now.year) {
    return DateFormat('d \'de\' MMMM', 'es_ES').format(date);
  } else {
    return DateFormat('d \'de\' MMMM \'de\' y', 'es_ES').format(date);
  }
}

/// Pantalla que muestra la lista de todas las transacciones del usuario
class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : AppColors.backgroundColor;
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Fixed Premium Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Movimientos',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  _HeaderAction(
                    onTap: () async {
                      final transactions = transactionsAsync.asData?.value;
                      if (transactions != null && transactions.isNotEmpty) {
                         await showSearch(
                          context: context,
                          delegate: _TransactionSearchDelegate(transactions, ref),
                        );
                      }
                    },
                    icon: Icons.search_rounded,
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: transactionsAsync.when(
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
              const TransactionFiltersBar(), // Fixed at top
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 120),
                  physics: const BouncingScrollPhysics(),
                  itemCount: transactions.length + 1, // +1 para el SummaryCard
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSummaryCard(context, ref, isDark);
                    }
                    
                    final txIndex = index - 1;
                    final transaction = transactions[txIndex];
                    final showHeader = txIndex == 0 ||
                        transactions[txIndex - 1].fecha.day != transaction.fecha.day ||
                        transactions[txIndex - 1].fecha.month != transaction.fecha.month ||
                        transactions[txIndex - 1].fecha.year != transaction.fecha.year;

                    if (showHeader) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20, top: 20, bottom: 8),
                            child: Text(
                              _formatDateHeader(transaction.fecha),
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w600,
                                fontSize: AppColors.bodyMedium,
                                color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.7),
                              ),
                            ),
                          ),
                          TransactionTile(
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
                          ),
                        ],
                      );
                    }
                    
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
      ), // Cierra async when
    ), // Cierra Expanded
  ], // Cierra children de Column
), // Cierra Column
    );
  }

  Widget _buildSummaryCard(BuildContext context, WidgetRef ref, bool isDark) {
    final summary = ref.watch(filteredTransactionsSummaryProvider);
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    
    // Homologación con la card de balance del dashboard
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withRed(30).withGreen(100),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Balance Total del Periodo (Mejora visual para fondo primario)
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance del Periodo',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    currencyFormatter.format(summary.total),
                    style: GoogleFonts.montserrat(
                      fontSize: 22, // Aumentado para mayor énfasis visual
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Separador Vertical sutil
          Container(
            height: 35, // Ligeramente más alto para acompañar el nuevo tamaño
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withOpacity(0.2),
          ),
          
          // Ingresos y Gastos Compactos (Adaptados al fondo primario)
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactSummaryItem(
                    amount: summary.income,
                    color: Colors.greenAccent,
                    icon: Icons.add_circle_outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactSummaryItem(
                    amount: summary.expenses,
                    color: Colors.white.withOpacity(0.9),
                    icon: Icons.remove_circle_outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummaryItem({
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    final compactFormatter = NumberFormat.compactCurrency(symbol: '\$');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color), // Icono más visible
            const SizedBox(width: 4),
            Text(
              amount >= 0 ? compactFormatter.format(amount) : compactFormatter.format(amount.abs()),
              style: GoogleFonts.montserrat(
                fontSize: 16, // Aumentado significativamente para jerarquía visual
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.2, // Menor espaciado para mejor aspecto
              ),
            ),
          ],
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

// Botón de acción en el header homologado
class _HeaderAction extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;

  const _HeaderAction({required this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10), // Squircle
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
      ),
    );
  }
}
