import 'package:finanzas/core/widgets/app_shell.dart';
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
import '../providers/transaction_filters_provider.dart';
import '../../../../core/services/finance_service.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../../core/widgets/app_shell.dart';
import 'dart:convert';

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

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showArchived = false;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && _searchController.text.isEmpty) {
        if (_isSearchOpen && mounted) {
          setState(() => _isSearchOpen = false);
        }
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (!_isSearchOpen) {
        _searchController.clear();
        _searchFocus.unfocus();
        ref.read(transactionFiltersProvider.notifier).update((state) => state.copyWith(searchQuery: ''));
      } else {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Fixed Premium Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Movimientos',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _HeaderAction(
                        onTap: _toggleSearch,
                        icon: Icons.search_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildExportMenu(context),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Inline Search Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isSearchOpen ? 60 : 0,
            child: ClipRect(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          // Oculta el teclado pero mantiene el buscador visible
                          _searchFocus.unfocus();
                        },
                        onChanged: (val) {
                          ref.read(transactionFiltersProvider.notifier).update((state) => state.copyWith(searchQuery: val));
                        },
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar monto, categoría, estatus...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black54, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty 
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: isDark ? Colors.white54 : Colors.black54, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(transactionFiltersProvider.notifier).update((state) => state.copyWith(searchQuery: ''));
                                    // Mantiene el foco para poder escribir otra cosa
                                    _searchFocus.requestFocus();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _toggleSearch,
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Expanded(
            child: transactionsAsync.when(
              data: (allTransactions) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          final archivedTransactions = allTransactions.where((t) {
            return t.fecha.isBefore(today.add(const Duration(days: 1))) && 
                   (t.estado == 'completada' || t.estado == 'pagada');
          }).toList();
          
          final activeTransactions = allTransactions.where((t) {
            return !(t.fecha.isBefore(today.add(const Duration(days: 1))) && 
                    (t.estado == 'completada' || t.estado == 'pagada'));
          }).toList();
          
          final displayedTransactions = _showArchived ? allTransactions : activeTransactions;
          final pendingTransactions = displayedTransactions.where((t) => t.estado == 'pendiente').toList();
          final summary = ref.watch(filteredTransactionsSummaryProvider);
          final hasPending = summary.pendingIncome != 0 || summary.pendingExpenses != 0;

          if (allTransactions.isEmpty && !hasPending) {
            final hasFilters = _hasAnyFilter(ref.watch(transactionFiltersProvider));
            return Column(
              children: [
                Expanded(
                  child: _buildEmptyStateBox(context, hasFilters, isDark),
                ),
              ],
            );
          }

          return Column(
            children: [
              // Hint for Spotlight
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Desliza para buscar',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels < -60 && notification.dragDetails != null && !_isSearchOpen) {
                      _toggleSearch();
                    }
                    return false;
                  },
                  child: Column(
                    children: [
                      _buildModernSummaryCard(
                        title: (_hasAnyFilter(ref.watch(transactionFiltersProvider))) ? 'Balance del Periodo' : 'Balance General',
                        total: summary.total,
                        income: summary.income,
                        expenses: summary.expenses,
                        pendingIncome: summary.pendingIncome,
                        pendingExpenses: summary.pendingExpenses,
                        isDark: isDark,
                        gradient: [
                          AppColors.primary,
                          AppColors.primary.withRed(30).withGreen(100),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(child: _buildTransactionList(displayedTransactions, isDark, ref, archivedCount: archivedTransactions.length)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateBox(BuildContext context, bool hasFilters, bool isDark) {
    return Center(
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
            hasFilters 
                ? 'Sin resultados' 
                : 'Sin transacciones',
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
    );
  }

  Widget _buildTransactionList(List<TransactionModel> transactions, bool isDark, WidgetRef ref, {bool isPendingList = false, int archivedCount = 0}) {
    if (transactions.isEmpty && archivedCount == 0) {
      return _buildEmptyStateBox(context, false, isDark);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 160),
      physics: const BouncingScrollPhysics(),
      itemCount: transactions.length + (archivedCount > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == transactions.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _showArchived = !_showArchived);
                  ref.read(financeServiceProvider).refreshAll();
                },
                icon: Icon(
                  _showArchived ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                label: Text(
                  _showArchived ? 'Ocultar archivadas' : 'Ver archivadas ($archivedCount)',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }

        final transaction = transactions[index];
        final showHeader = index == 0 ||
            transactions[index - 1].fecha.day != transaction.fecha.day ||
            transactions[index - 1].fecha.month != transaction.fecha.month ||
            transactions[index - 1].fecha.year != transaction.fecha.year;

        if (showHeader) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 4, bottom: 0),
                child: Text(
                  _formatDateHeader(transaction.fecha),
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: isDark ? Colors.white54 : AppColors.textPrimary.withOpacity(0.5),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              TransactionTile(
                key: ValueKey('header_${transaction.id}'),
                transaction: transaction,
                currencySymbol: '\$',
              ),
            ],
          );
        }
        
        return TransactionTile(
          key: ValueKey(transaction.id),
          transaction: transaction,
          currencySymbol: '\$',
        );
      },
    );
  }

  Widget _buildModernSummaryCard({
    required String title,
    required double total,
    required double income,
    required double expenses,
    double pendingIncome = 0.0,
    double pendingExpenses = 0.0,
    required bool isDark,
    required List<Color> gradient, // Se ignora
  }) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    
    final bgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F7FA);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
    final titleColor = isDark ? Colors.white54 : Colors.black54;
    final balanceColor = isDark ? Colors.white : AppColors.textPrimary;
    
    final hasPending = pendingIncome > 0 || pendingExpenses > 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lado Izquierdo: Balance Total
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currencyFormatter.format(total),
                    style: GoogleFonts.montserrat(
                      fontSize: 30, // Más grande
                      fontWeight: FontWeight.w800,
                      color: balanceColor,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            width: 1,
            height: hasPending ? 70 : 40,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: borderColor,
          ),
          
          // Lado Derecho: Indicadores (Ingresos, Gastos, Pendientes)
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildFlatMetric(
                        label: 'INGRESOS',
                        amount: income,
                        color: isDark ? Colors.greenAccent : Colors.green[700]!,
                        isDark: isDark,
                        icon: Icons.arrow_downward_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildFlatMetric(
                        label: 'GASTOS',
                        amount: expenses,
                        color: isDark ? Colors.redAccent : Colors.red[700]!,
                        isDark: isDark,
                        icon: Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),
                if (hasPending) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: borderColor),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFlatMetric(
                          label: 'COBRAR',
                          amount: pendingIncome,
                          color: isDark ? Colors.tealAccent : Colors.teal[700]!,
                          isDark: isDark,
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                      Expanded(
                        child: _buildFlatMetric(
                          label: 'PAGAR',
                          amount: pendingExpenses,
                          color: isDark ? Colors.orange[300]! : Colors.orange[800]!,
                          isDark: isDark,
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatMetric({
    required String label,
    required double amount,
    required Color color,
    required bool isDark,
    required IconData icon,
  }) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'en_US');
    if (amount >= 1000000) {
      currencyFormatter.maximumFractionDigits = 1;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color.withOpacity(0.9)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black54,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          amount >= 1000000 
            ? NumberFormat.compactCurrency(symbol: '\$', locale: 'en_US').format(amount)
            : currencyFormatter.format(amount),
          style: GoogleFonts.montserrat(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.3,
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

  Widget _buildExportMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Exportar',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _exportTransactions,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'csv',
          child: Row(
            children: [
              const Icon(Icons.table_chart_outlined, size: 18),
              const SizedBox(width: 8),
              Text('Export as CSV', style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'json',
          child: Row(
            children: [
              const Icon(Icons.data_object_rounded, size: 18),
              const SizedBox(width: 8),
              Text('Export as JSON', style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium)),
            ],
          ),
        ),
      ],
    );
  }

  void _exportTransactions(String format) {
    final transactionsAsync = ref.read(filteredTransactionsProvider);
    final allTransactions = transactionsAsync.asData?.value ?? [];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final activeTransactions = allTransactions.where((t) {
      return !(t.fecha.isBefore(today.add(const Duration(days: 1))) && 
              (t.estado == 'completada' || t.estado == 'pagada'));
    }).toList();
    
    final displayedTransactions = _showArchived ? allTransactions : activeTransactions;
    final exportTransactions = displayedTransactions;

    if (exportTransactions.isEmpty) {
      showAppToast(context, message: 'No hay transacciones para exportar', type: ToastType.warning);
      return;
    }
    
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filename = 'finanzas_movimientos_$dateStr';

    try {
      if (format == 'csv') {
        final header = 'ID,Fecha,Monto,Tipo,CategoriaID,CuentaID,Estado,Descripcion\n';
        final buffer = StringBuffer(header);
        for (final t in exportTransactions) {
          final date = DateFormat('yyyy-MM-dd HH:mm').format(t.fecha);
          final desc = t.descripcion?.replaceAll('"', '""') ?? '';
          final line = '${t.id},$date,${t.monto},${t.tipo},${t.categoriaId ?? ""},${t.cuentaOrigenId ?? ""},${t.estado},"$desc"\n';
          buffer.write(line);
        }
        downloadFile('$filename.csv', buffer.toString(), 'text/csv');
      } else if (format == 'json') {
        final jsonList = exportTransactions.map((t) => {
          'id': t.id,
          'fecha': t.fecha.toIso8601String(),
          'monto': t.monto,
          'tipo': t.tipo,
          'categoria_id': t.categoriaId,
          'cuenta_id': t.cuentaOrigenId,
          'estado': t.estado,
          'descripcion': t.descripcion,
        }).toList();
        final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonList);
        downloadFile('$filename.json', jsonStr, 'application/json');
      }
      
      showAppToast(context, message: 'Exportación iniciada', type: ToastType.success);
    } catch (e) {
      showAppToast(context, message: 'Error al exportar: $e', type: ToastType.error);
    }
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
  final bool hasBadge;

  const _HeaderAction({
    required this.onTap, 
    required this.icon,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          if (hasBadge)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark(context) ? const Color(0xFF121212) : Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      onPressed: onTap,
    );
  }

  bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;
}
