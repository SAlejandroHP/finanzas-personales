import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/presentation/providers/recurring_warnings_provider.dart';
import '../../../../core/widgets/bank_logo.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../transactions/presentation/widgets/transaction_form_sheet.dart';

/// Pantalla del dashboard que muestra un resumen financiero.
/// Permite navegar a cuentas, categorías y transacciones.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundColor;
    final totalBalance = ref.watch(totalBalanceProvider);
    final monthlyIncome = ref.watch(monthlyIncomeProvider);
    final monthlyExpenses = ref.watch(monthlyExpensesProvider);
    final accounts = ref.watch(accountsWithBalanceProvider);
    final pendingTransactions = ref.watch(pendingTransactionsProvider);
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surface;

    // Formateador de moneda estándar
    final currencyFormatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    // Formateador MXN específico para saldo total (Requisito 1)
    final mxnFormatter = NumberFormat.currency(
      locale: 'es_MX',
      symbol: 'MXN ',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppColors.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ref),
              _buildWarningsSection(context, ref),
              const SizedBox(height: 16),
              _buildBalanceSummaryCard(
                context,
                totalBalance,
                monthlyIncome,
                monthlyExpenses,
                mxnFormatter,
                currencyFormatter,
                cardColor,
                isDark,
              ),
              const SizedBox(height: 24),
              _buildAccountsAndCardsSection(
                context,
                accounts,
                currencyFormatter,
                isDark,
                cardColor,
              ),
              const SizedBox(height: 24),
              _buildCategoryStatsCard(context, ref, cardColor, isDark),
              const SizedBox(height: 24),
              _buildRecentTransactionsCard(
                context,
                ref,
                pendingTransactions,
                currencyFormatter,
                isDark,
                cardColor,
              ),
              const SizedBox(height: 24),
              _buildActiveDebtsCard(
                context,
                ref,
                currencyFormatter,
                isDark,
                cardColor,
              ),
              const SizedBox(height: 100), // Espacio para el nav island
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningsSection(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(recurringWarningsProvider);
    if (warnings.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: warnings.map((warning) {
        final isVence = warning.type == WarningType.vence;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(AppColors.contentGap),
          decoration: BoxDecoration(
            color: isVence
                ? Colors.red.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppColors.radiusLarge),
            border: Border.all(
              color: isVence
                  ? Colors.red.withOpacity(0.3)
                  : AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isVence
                    ? Icons.warning_amber_rounded
                    : Icons.lightbulb_outline_rounded,
                color: isVence ? Colors.red : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppColors.contentGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warning.title,
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodySmall,
                        fontWeight: FontWeight.w700,
                        color: isVence ? Colors.red : AppColors.primary,
                      ),
                    ),
                    Text(
                      warning.message,
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodySmall,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(transactionsNotifierProvider.notifier)
                        .payRecurringEarly(warning.transaction);
                    if (context.mounted) {
                      showAppToast(
                        context,
                        message: 'Pago realizado con éxito',
                        type: ToastType.success,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showAppToast(
                        context,
                        message: 'Error: $e',
                        type: ToastType.error,
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Pagar ahora',
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodySmall,
                    fontWeight: FontWeight.w700,
                    color: isVence ? Colors.red : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warnings = ref.watch(recurringWarningsProvider);
    final notificationCount = warnings.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, Alejandro',
              style: GoogleFonts.montserrat(
                fontSize: AppColors.titleLarge,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            Text(
              DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: GoogleFonts.montserrat(
                fontSize: AppColors.bodyMedium,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => context.push('/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              if (notificationCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundColor,
                        width: 2,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        notificationCount > 9
                            ? '9+'
                            : notificationCount.toString(),
                        style: GoogleFonts.montserrat(
                          fontSize: AppColors.bodySmall,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceSummaryCard(
    BuildContext context,
    double balance,
    double incomes,
    double expenses,
    NumberFormat balanceFormatter,
    NumberFormat flowFormatter,
    Color cardColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppColors.cardPadding),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Parte del Saldo (8 columnas aproximadas por flex)
            Expanded(
              flex: 8,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppColors.contentGap),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppColors.contentGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Saldo Disponible',
                          style: GoogleFonts.montserrat(
                            fontSize: AppColors.bodySmall,
                            color: isDark
                                ? Colors.white70
                                : AppColors.textPrimary.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          balanceFormatter.format(balance),
                          style: GoogleFonts.montserrat(
                            fontSize: AppColors.bodyLarge,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Separador vertical sutil
            VerticalDivider(
              width: 32,
              thickness: 1,
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),

            // Parte de Ingresos/Gastos (4 columnas aproximadas por flex)
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFlowRow(
                    'Ingresos',
                    incomes,
                    Colors.green,
                    Icons.arrow_circle_up,
                    prefix: '+',
                  ),
                  const SizedBox(height: 12),
                  _buildFlowRow(
                    'Gastos',
                    expenses,
                    Colors.red,
                    Icons.arrow_circle_down,
                    prefix: '-',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowRow(
    String label,
    double amount,
    Color color,
    IconData icon, {
    String prefix = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "$prefix\n${NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(amount)}",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 12,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsAndCardsSection(
    BuildContext context,
    AsyncValue accounts,
    NumberFormat currencyFormatter,
    bool isDark,
    Color cardColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CUENTAS',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withOpacity(0.8),
                  letterSpacing: 1.1,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/accounts'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ver todas',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        accounts.when(
          data: (list) {
            final allAccounts = (list as List).toList();

            if (allAccounts.isEmpty) {
              return Center(
                child: Text(
                  'No tienes cuentas registradas',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              );
            }
            return GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: allAccounts.length,
              itemBuilder: (context, index) {
                final acc = allAccounts[index];
                final isTC = acc.tipo == 'tarjeta_credito';

                // Obtener tema para el tipo (consistente con AccountCard)
                Color typeColor;
                IconData typeIcon;
                String typeLabel;

                switch (acc.tipo) {
                  case 'efectivo':
                    typeColor = Colors.green;
                    typeIcon = Icons.payments_outlined;
                    typeLabel = 'Efectivo';
                    break;
                  case 'chequera':
                    typeColor = Colors.blue;
                    typeIcon = Icons.account_balance_outlined;
                    typeLabel = 'Débito';
                    break;
                  case 'ahorro':
                    typeColor = Colors.purple;
                    typeIcon = Icons.savings_outlined;
                    typeLabel = 'Ahorros';
                    break;
                  case 'tarjeta_credito':
                    typeColor = Colors.red;
                    typeIcon = Icons.credit_card_outlined;
                    typeLabel = 'Crédito';
                    break;
                  case 'inversion':
                    typeColor = Colors.orange;
                    typeIcon = Icons.trending_up_outlined;
                    typeLabel = 'Inversión';
                    break;
                  default:
                    typeColor = Colors.blueGrey;
                    typeIcon = Icons.help_outline;
                    typeLabel = 'Otro';
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: typeColor.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/accounts/detail/${acc.id}'),
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: 0,
                            left: 15,
                            right: 15,
                            height: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.3),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (acc.bancoLogo != null &&
                                        acc.bancoLogo!.isNotEmpty)
                                      BankLogo(
                                        bankName: acc.bancoNombre ?? acc.nombre,
                                        primaryColor: typeColor.value
                                            .toRadixString(16)
                                            .padLeft(8, '0')
                                            .substring(2),
                                        size: 24,
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: typeColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          typeIcon,
                                          size: 12,
                                          color: typeColor,
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            acc.nombre,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            typeLabel,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  isTC ? 'Disponible' : 'Saldo',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currencyFormatter.format(acc.saldoActual),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isTC) ...[
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: acc.saldoInicial > 0
                                          ? ((acc.saldoInicial -
                                                    acc.saldoActual) /
                                                acc.saldoInicial)
                                          : 0,
                                      minHeight: 2,
                                      backgroundColor: isDark
                                          ? Colors.white10
                                          : Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        ((acc.saldoInicial - acc.saldoActual) /
                                                    acc.saldoInicial) >
                                                0.8
                                            ? Colors.red
                                            : typeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Error'),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue pendingTransactions,
    NumberFormat formatter,
    bool isDark,
    Color cardColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PAGOS PENDIENTES',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withOpacity(0.8),
                  letterSpacing: 1.1,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/transactions'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ver todas',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: pendingTransactions.when(
            data: (txs) {
              final list = (txs as List).toList();

              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No hay pagos pendientes',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return Column(
                children: list.take(5).map((tx) {
                  final isExpense =
                      tx.tipo == 'gasto' ||
                      tx.tipo == 'deuda_pago' ||
                      tx.tipo == 'meta_aporte';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        _buildCompactCategoryIcon(ref, tx),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.descripcion ?? 'Sin desc.',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                DateFormat('dd MMM, yyyy').format(tx.fecha),
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isExpense ? '-' : '+'}${formatter.format(tx.monto)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isExpense
                                    ? Colors.red[400]
                                    : Colors.green[400],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: tx.estado == 'completa'
                                        ? Colors.green
                                        : Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tx.estado == 'completa'
                                      ? 'PAGADO'
                                      : 'PENDIENTE',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey[500],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Text('Error al cargar'),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryStatsCard(
    BuildContext context,
    WidgetRef ref,
    Color cardColor,
    bool isDark,
  ) {
    final transactionsAsync = ref.watch(transactionsListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GASTO POR CATEGORÍA',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary.withOpacity(0.8),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          transactionsAsync.when(
            data: (transactions) {
              return categoriesAsync.when(
                data: (categories) {
                  // Filtrar solo gastos
                  final expensesOnly = (transactions as List)
                      .where(
                        (tx) =>
                            tx.tipo == 'gasto' ||
                            tx.tipo == 'deuda_pago' ||
                            tx.tipo == 'meta_aporte',
                      )
                      .toList();

                  if (expensesOnly.isEmpty) {
                    return const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text(
                          'Sin datos',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  }

                  // Agrupar por categoría
                  final Map<String, double> categoryMap = {};

                  for (final tx in expensesOnly) {
                    final catId = tx.categoriaId ?? 'sin_cat';
                    categoryMap[catId] = (categoryMap[catId] ?? 0) + tx.monto;
                  }

                  // Ordenar y tomar top 5 para la leyenda
                  final sortedCats = categoryMap.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  final topForChart = sortedCats.take(4).toList();
                  final topForLegend = sortedCats.take(5).toList();

                  return Column(
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            height: 100,
                            width: 100,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 20,
                                sections: topForChart.map((entry) {
                                  final category = categories.firstWhere(
                                    (c) => c.id == entry.key,
                                    orElse: () => categories.first,
                                  );

                                  Color color = AppColors.primary;
                                  if (category.color != null) {
                                    try {
                                      String colorStr = category.color!
                                          .replaceAll('#', '');
                                      if (colorStr.length == 6)
                                        colorStr = 'FF$colorStr';
                                      color = Color(
                                        int.parse(colorStr, radix: 16),
                                      );
                                    } catch (_) {}
                                  }

                                  return PieChartSectionData(
                                    color: color,
                                    value: entry.value,
                                    title: '',
                                    radius: 20,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: topForLegend.map((entry) {
                                final category = categories.firstWhere(
                                  (c) => c.id == entry.key,
                                  orElse: () => categories.first,
                                );

                                Color dotColor = AppColors.primary;
                                if (category.color != null) {
                                  try {
                                    String colorStr = category.color!
                                        .replaceAll('#', '');
                                    if (colorStr.length == 6)
                                      colorStr = 'FF$colorStr';
                                    dotColor = Color(
                                      int.parse(colorStr, radix: 16),
                                    );
                                  } catch (_) {}
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          category.nombre,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        NumberFormat.compactCurrency(
                                          symbol: '\$',
                                        ).format(entry.value),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text('Error'),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Text('Error'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDebtsCard(
    BuildContext context,
    WidgetRef ref,
    NumberFormat formatter,
    bool isDark,
    Color cardColor,
  ) {
    final debtsAsync = ref.watch(debtsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DEUDAS PENDIENTES',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withOpacity(0.8),
                  letterSpacing: 1.1,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/settings/debts'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ver todas',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: debtsAsync.when(
            data: (debts) {
              // Filtramos deudas para mostrar solo las que no están vinculadas a una cuenta (deudas externas)
              // o las que el usuario marcó como activas con monto pendiente.
              final List<dynamic> activeDebts = debts
                  .where(
                    (d) => d.estado == 'activa' && d.montoRestante > 0,
                  )
                  .toList();

              if (activeDebts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.grey.withOpacity(0.5),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No hay deudas pendientes',
                          style: GoogleFonts.montserrat(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: activeDebts.take(3).map((debt) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.money_off_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                debt.nombre,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (debt.fechaVencimiento != null)
                                Text(
                                  'Vence: ${DateFormat('dd MMM').format(debt.fechaVencimiento!)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                )
                              else
                                Text(
                                  _formatDebtType(debt.tipo),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatter.format(debt.montoRestante),
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange[400],
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => showTransactionFormSheet(
                                context,
                                transaction: TransactionModel(
                                  id: '', // Nueva
                                  userId: '',
                                  tipo: 'pago_deuda',
                                  monto: 0,
                                  fecha: DateTime.now(),
                                  estado: 'completa',
                                  cuentaOrigenId: '', // Requerido
                                  deudaId: debt.id,
                                  createdAt: DateTime.now(),
                                  isRecurring: false,
                                  autoComplete: false,
                                  weekendAdjustment: false,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Pagar ahora',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Text('Error al cargar'),
          ),
        ),
      ],
    );
  }

  String _formatDebtType(String tipo) {
    switch (tipo) {
      case 'prestamo_personal':
        return 'Personal';
      case 'prestamo_bancario':
        return 'Bancario';
      case 'servicio':
        return 'Servicio';
      default:
        return 'Otro';
    }
  }

  /// Construye un icono compacto de categoría
  Widget _buildCompactCategoryIcon(WidgetRef ref, TransactionModel tx) {
    if (tx.categoriaId == null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[400],
        ),
        child: const Icon(
          Icons.description_outlined,
          color: Colors.white,
          size: 16,
        ),
      );
    }

    final categoriesAsync = ref.watch(categoriesListProvider);

    return categoriesAsync.when(
      data: (categories) {
        try {
          final category = categories.firstWhere(
            (cat) => cat.id == tx.categoriaId,
          );

          Color backgroundColor = AppColors.primary;
          if (category.color != null && category.color!.isNotEmpty) {
            try {
              String colorString = category.color!.replaceAll('#', '').trim();
              if (colorString.length == 6) {
                colorString = 'FF$colorString';
              }
              final colorValue = int.parse(colorString, radix: 16);
              backgroundColor = Color(colorValue);
            } catch (e) {
              backgroundColor = AppColors.primary;
            }
          }

          IconData iconData = _getIconFromString(category.icono);

          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
            ),
            child: Icon(iconData, color: Colors.white, size: 16),
          );
        } catch (e) {
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[400],
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 16,
            ),
          );
        }
      },
      loading: () => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[400],
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      error: (_, __) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[400],
        ),
        child: const Icon(
          Icons.description_outlined,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  /// Corrección: Mapea el string del ícono a IconData de Material Icons
  /// Basado en los valores almacenados en la BD desde category_form_bottom_sheet.dart
  IconData _getIconFromString(String? iconName) {
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

    if (iconName == null || iconName.isEmpty) {
      return Icons.description_outlined;
    }

    return iconMap[iconName] ?? Icons.description_outlined;
  }
}
