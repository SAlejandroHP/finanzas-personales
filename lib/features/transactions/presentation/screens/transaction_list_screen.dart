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
import '../widgets/spotlight_search_overlay.dart';
import '../providers/transaction_filters_provider.dart';
import '../../../../core/services/finance_service.dart';
import '../../../../core/utils/download_helper.dart';
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
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showArchived = false;
  bool _isSpotlightOpen = false;

  void _openSpotlight() {
    if (_isSpotlightOpen) return;
    _isSpotlightOpen = true;
    
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => const SpotlightSearchOverlay(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ).then((_) {
      _isSpotlightOpen = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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
                        onTap: _openSpotlight,
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
              // Indicadores (Tabs) fijos arriba del PageView
              if (hasPending) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTabDot(0, 'General', isDark),
                    _buildTabDot(1, 'Pendientes', isDark),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Expanded(
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels < -60 && notification.dragDetails != null && !_isSpotlightOpen) {
                      _openSpotlight();
                    }
                    return false;
                  },
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                    // --- PESTAÑA 1: Balance del Periodo y Todas las transacciones ---
                    Column(
                      children: [
                        _buildModernSummaryCard(
                          title: 'Balance del Periodo',
                          total: summary.total,
                          income: summary.income,
                          expenses: summary.expenses,
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
                    
                    // --- PESTAÑA 2: Compromisos y Pendientes ---
                    if (hasPending)
                      Column(
                        children: [
                          _buildCommitmentSummaryCard(
                            title: 'Balance',
                            total: summary.pendingTotal,
                            income: summary.pendingIncome,
                            expenses: summary.pendingExpenses,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          Expanded(child: _buildTransactionList(pendingTransactions, isDark, ref, isPendingList: true)),
                        ],
                      ),
                  ],
                ),
              ),
              ),
            ],
          );
        },
        loading: () => const Column(
          children: [
            Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ],
        ),
        error: (error, stackTrace) => Column(
          children: [
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
                      onPressed: () => ref.read(financeServiceProvider).refreshAll(),
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
                : (_currentPage == 1 ? 'Sin compromisos' : 'Sin transacciones'),
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
                : (_currentPage == 1 
                    ? 'No tienes pagos pendientes en este periodo' 
                    : 'Comienza a registrar tus movimientos'),
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

  Widget _buildTabDot(int index, String label, bool isDark) {
    final isSelected = _currentPage == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary.withOpacity(0.5) : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.primary : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  // Card con gradiente para el balance principal
  Widget _buildModernSummaryCard({
    required String title,
    required double total,
    required double income,
    required double expenses,
    required bool isDark,
    required List<Color> gradient,
  }) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
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
                    currencyFormatter.format(total),
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 30, // Unificado a 30
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white.withOpacity(0.2),
          ),
          Expanded(
            flex: 4, // Unificado a 4 para que sea una columna delgada
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompactSummaryItem(
                  amount: income,
                  color: Colors.greenAccent,
                  icon: Icons.add_circle_outline,
                ),
                const SizedBox(height: 4), // Gap para la pila
                _buildCompactSummaryItem(
                  amount: expenses,
                  color: Colors.white.withOpacity(0.9),
                  icon: Icons.remove_circle_outline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card minimalista con columna vertical para compromisos
  Widget _buildCommitmentSummaryCard({
    required String title,
    required double total,
    required double income,
    required double expenses,
    required bool isDark,
  }) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        border: Border.all(
          color: AppColors.secondary.withOpacity(isDark ? 0.3 : 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    currencyFormatter.format(total),
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 30,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompactSummaryItem(
                  amount: income,
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                  icon: Icons.add_circle_outline,
                ),
                const SizedBox(height: 4),
                _buildCompactSummaryItem(
                  amount: expenses,
                  color: AppColors.secondary,
                  icon: Icons.remove_circle_outline,
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
    final absAmount = amount.abs();
    final String formattedText;

    // Si el monto es menor a 1 millón, lo mostramos completo (ej: $17,500) para mayor precisión.
    if (absAmount < 1000000) {
      formattedText = NumberFormat.currency(
        symbol: '\$',
        decimalDigits: 0,
        locale: 'en_US', // Asegura separadores de miles con coma
      ).format(absAmount);
    } else {
      // Para montos muy grandes usamos el formato compacto (K, M) para no romper el layout.
      formattedText = NumberFormat.compactCurrency(
        symbol: '\$',
        locale: 'en_US',
      ).format(absAmount);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          formattedText,
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
    final exportTransactions = _currentPage == 1 
        ? displayedTransactions.where((t) => t.estado == 'pendiente').toList()
        : displayedTransactions;

    if (exportTransactions.isEmpty) {
      showAppToast(context, message: 'No hay transacciones para exportar', type: ToastType.warning);
      return;
    }
    
    final tabName = _currentPage == 0 ? 'General' : 'Pendientes';
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filename = 'finanzas_${tabName.toLowerCase()}_$dateStr';

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
