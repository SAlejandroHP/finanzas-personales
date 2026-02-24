import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/models/category_model.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/bank_logo.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../transactions/presentation/widgets/transaction_form_sheet.dart';

/// Pantalla del dashboard que muestra un resumen financiero.
/// Permite navegar a cuentas, categorías y transacciones.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int touchedIndex = -1;
  String periodFilter = 'Este mes';
  bool _showAllCategories = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundColor;
    final totalBalance = ref.watch(totalBalanceProvider);
    final totalDebts = ref.watch(totalDebtsProvider);
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
        child: RefreshIndicator(
          onRefresh: () async {
            // Refresca los proveedores principales del dashboard
            ref.invalidate(totalBalanceProvider);
            ref.invalidate(accountsWithBalanceProvider);
            ref.invalidate(transactionsListProvider);
            ref.invalidate(pendingTransactionsProvider);
            ref.invalidate(debtsListProvider);
            // Pequeño delay artificial para que el usuario sienta la actualización
            await Future.delayed(const Duration(milliseconds: 1200));
          },
          displacement: 20,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(), // Necesario para RefreshIndicator
            padding: const EdgeInsets.all(AppColors.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, ref),
                _buildBalanceSummaryCard(
                  context,
                  totalBalance,
                  totalDebts,
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
                _buildCategoryStatsCard(context, cardColor, isDark),
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    // Obtener nombre del usuario si está disponible a través de metadatos o email
    String? userName;
    if (user != null) {
      if (user.userMetadata != null) {
        userName = user.userMetadata?['full_name'] ?? 
                   user.userMetadata?['name'] ?? 
                   user.userMetadata?['first_name'];
      }
      // Fallback a primera parte del email si no hay nombre
      userName ??= user.email?.split('@')[0];
    }

    // Capitalizar primera letra del nombre
    if (userName != null && userName.isNotEmpty) {
      userName = userName[0].toUpperCase() + userName.substring(1);
    }

    // Obtener saludo según la hora
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = userName != null ? 'Buenos días, $userName' : 'Buenos días';
    } else if (hour < 19) {
      greeting = userName != null ? 'Buenas tardes, $userName' : 'Buenas tardes';
    } else {
      greeting = userName != null ? 'Buenas noches, $userName' : 'Buenas noches';
    }

    // Fecha actual para el reloj
    final now = DateTime.now();
    final formattedDate = DateFormat('EEE, d MMM', 'es_MX').format(now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.bodySmall,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                'Tu Resumen',
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.titleLarge,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          _buildDateClock(context, isDark, formattedDate),
        ],
      ),
    );
  }

  /// Construye un pequeño widget con la fecha e icono de calendario
  Widget _buildDateClock(BuildContext context, bool isDark, String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.05) 
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: isDark ? Colors.white38 : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            date.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummaryCard(
    BuildContext context,
    double balance,
    double totalDebts,
    double incomes,
    double expenses,
    NumberFormat balanceFormatter,
    NumberFormat flowFormatter,
    Color cardColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withRed(30).withGreen(100), // Un teal más profundo/vibrante
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        child: Stack(
          children: [
            // Círculos decorativos para efecto Glassmorphism Premium
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LIQUIDEZ TOTAL',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.7),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            balanceFormatter.format(balance),
                            style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded, 
                              color: Colors.white, 
                              size: 18
                            ),
                          ),
                          if (totalDebts > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'DEUDA ',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withOpacity(0.6),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  flowFormatter.format(totalDebts),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 14),
                  
                  // Sección inferior (Glass bar) más compacta
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFlowColumn(
                            'Ingresos',
                            incomes,
                            Colors.white,
                            Icons.arrow_upward_rounded,
                          ),
                        ),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.white.withOpacity(0.15),
                        ),
                        Expanded(
                          child: _buildFlowColumn(
                            'Gastos',
                            expenses,
                            Colors.white,
                            Icons.arrow_downward_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowColumn(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(amount),
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
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
                'MIS CUENTAS',
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.bodySmall,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary.withOpacity(0.8),
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/accounts'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      'Gestionar',
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodySmall,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                  ],
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
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                ),
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, 
                         size: 32, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'No hay cuentas activas',
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodySmall,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 140, // Altura fija para el scroll horizontal
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: allAccounts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final acc = allAccounts[index];
                  final isTC = acc.tipo == 'tarjeta_credito';

                  Color typeColor;
                  IconData typeIcon;

                  switch (acc.tipo) {
                    case 'efectivo':
                      typeColor = Colors.green;
                      typeIcon = Icons.payments_outlined;
                      break;
                    case 'chequera':
                      typeColor = Colors.blue;
                      typeIcon = Icons.account_balance_outlined;
                      break;
                    case 'ahorro':
                      typeColor = Colors.purple;
                      typeIcon = Icons.savings_outlined;
                      break;
                    case 'tarjeta_credito':
                      typeColor = Colors.redAccent;
                      typeIcon = Icons.credit_card_outlined;
                      break;
                    case 'inversion':
                      typeColor = Colors.orange;
                      typeIcon = Icons.trending_up_outlined;
                      break;
                    default:
                      typeColor = Colors.blueGrey;
                      typeIcon = Icons.help_outline;
                  }

                  return Container(
                    width: 175, // Ligeramente más ancho
                    decoration: BoxDecoration(
                      gradient: isTC 
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark 
                                  ? [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)]
                                  : [Colors.white, const Color(0xFFF8F9FB)],
                            )
                          : null,
                      color: !isTC ? cardColor : null,
                      borderRadius: BorderRadius.circular(22), // Bordes más suaves Apple-style
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withOpacity(0.08) 
                            : (isTC ? Colors.red.withOpacity(0.1) : Colors.black.withOpacity(0.04)),
                        width: 1.2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/accounts/detail/${acc.id}'),
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          children: [
                            // Indicador visual discreto de tipo de cuenta
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.05),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(22),
                                    bottomLeft: Radius.circular(22),
                                  ),
                                ),
                                child: Icon(typeIcon, size: 14, color: typeColor.withOpacity(0.4)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (acc.bancoLogo != null && acc.bancoLogo!.isNotEmpty)
                                    BankLogo(
                                      bankName: acc.bancoNombre ?? acc.nombre,
                                      primaryColor: typeColor.value.toRadixString(16).padLeft(8, '0').substring(2),
                                      size: 32,
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: typeColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(typeIcon, size: 16, color: typeColor),
                                    ),
                                  const Spacer(),
                                  Text(
                                    acc.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white.withOpacity(0.6) : Colors.black54,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormatter.format(acc.saldoActual),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppColors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (isTC) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: acc.saldoInicial > 0
                                                  ? ((acc.saldoInicial - acc.saldoActual) / acc.saldoInicial)
                                                  : 0,
                                              minHeight: 4,
                                              backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                ((acc.saldoInicial - acc.saldoActual) / acc.saldoInicial) > 0.8
                                                    ? Colors.red[400]!
                                                    : typeColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(acc.saldoInicial > 0 ? ((acc.saldoInicial - acc.saldoActual) / acc.saldoInicial * 100) : 0).toInt()}%',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white38 : Colors.black38,
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
                      ),
                    ),
                  );
                },
              ),
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
                  fontSize: AppColors.bodySmall,
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
                    fontSize: AppColors.bodySmall,
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: pendingTransactions.when(
            data: (txs) {
              final list = (txs as List).toList();

              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'No tienes pagos para hoy',
                      style: GoogleFonts.montserrat(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: list.take(3).map((tx) {
                  final isExpense = tx.tipo == 'gasto' || tx.tipo == 'pago_deuda' || tx.tipo == 'meta_aporte';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        _buildCompactCategoryIcon(ref, tx),
                        const SizedBox(width: 12),
                        // Columna independiente para descripción con ajuste vertical
                        Expanded(
                          child: Text(
                            tx.descripcion ?? 'Transacción',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Monto y Fecha alineados a la derecha
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${isExpense ? '-' : '+'}${formatter.format(tx.monto)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isExpense ? (isDark ? Colors.red[300] : Colors.red[700]) : Colors.green[400],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM').format(tx.fecha),
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Acción rápida: Botón de pago Small (SM) minimalista
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Pago marcado como realizado',
                                    style: GoogleFonts.montserrat(fontSize: 12),
                                  ),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: 'DESHACER',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      // Lógica futura para revertir
                                    },
                                  ),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(6), // Tamaño SM
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12), // Color plano sutil
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14, // Icono SM
                                color: AppColors.primary,
                              ),
                            ),
                          ),
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

  /// Tarjeta de estadísticas por categoría.
  Widget _buildCategoryStatsCard(
    BuildContext context,
    Color cardColor,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gasto por Categoría',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              _buildPeriodSelector(isDark),
            ],
          ),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, child) {
              final transactionsAsync = ref.watch(transactionsListProvider);
              final categoriesAsync = ref.watch(categoriesListProvider);

              return transactionsAsync.when(
                data: (transactions) {
                  return categoriesAsync.when(
                    data: (categories) {
                      // 1. Filtrar transacciones por periodo y tipo 'gasto'
                      final now = DateTime.now();
                      final filteredTransactions = transactions.where((tx) {
                        final isExpense = tx.tipo == 'gasto' || tx.tipo == 'pago_deuda' || tx.tipo == 'meta_aporte';
                        if (!isExpense) return false;

                        if (periodFilter == 'Este mes') {
                          return tx.fecha.month == now.month && tx.fecha.year == now.year;
                        } else if (periodFilter == '30 días') {
                          return tx.fecha.isAfter(now.subtract(const Duration(days: 30)));
                        } else {
                          return tx.fecha.year == now.year;
                        }
                      }).toList();

                      // 2. Agrupar por categoría
                      final Map<String, double> categoryMap = {};
                      double totalExpenses = 0;

                      for (final tx in filteredTransactions) {
                        String catId;
                        if (tx.tipo == 'pago_deuda') {
                          catId = 'cat_pago_deuda';
                        } else if (tx.tipo == 'meta_aporte') {
                          catId = 'cat_meta_aporte';
                        } else {
                          catId = tx.categoriaId ?? 'sin_cat';
                        }
                        categoryMap[catId] = (categoryMap[catId] ?? 0) + tx.monto;
                        totalExpenses += tx.monto;
                      }

                      if (totalExpenses == 0) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'Sin gastos en este periodo',
                              style: GoogleFonts.montserrat(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      // 3. Preparar datos para la lista (ordenados por monto)
                      final sortedEntries = categoryMap.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      // Función auxiliar para obtener datos de categoría
                      CategoryModel getCategory(String id) {
                        if (id == 'cat_pago_deuda') {
                          return CategoryModel(
                            id: 'cat_pago_deuda',
                            userId: '',
                            nombre: 'Pagos Deuda',
                            tipo: 'gasto',
                            color: '#FF7043',
                            icono: 'credit_card',
                            createdAt: DateTime.now(),
                          );
                        } else if (id == 'cat_meta_aporte') {
                          return CategoryModel(
                            id: 'cat_meta_aporte',
                            userId: '',
                            nombre: 'Ahorro Metas',
                            tipo: 'gasto',
                            color: '#26A69A',
                            icono: 'savings',
                            createdAt: DateTime.now(),
                          );
                        } else if (id == 'sin_cat') {
                          return CategoryModel(
                            id: 'sin_cat',
                            userId: '',
                            nombre: 'Otros',
                            tipo: 'gasto',
                            color: '#9E9E9E',
                            icono: 'more_horiz',
                            createdAt: DateTime.now(),
                          );
                        }
                        return categories.firstWhere(
                          (c) => c.id == id,
                          orElse: () => CategoryModel(
                            id: 'unknown',
                            userId: '',
                            nombre: 'Desconocido',
                            tipo: 'gasto',
                            color: '#000000',
                            icono: 'category',
                            createdAt: DateTime.now(),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // Gráfica de Pie Interactiva con Total al centro
                          SizedBox(
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                        setState(() {
                                          if (!event.isInterestedForInteractions ||
                                              pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection == null) {
                                            touchedIndex = -1;
                                            return;
                                          }
                                          touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                        });
                                      },
                                    ),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: 4,
                                    centerSpaceRadius: 65,
                                    sections: sortedEntries.asMap().entries.map((entry) {
                                      final isTouched = entry.key == touchedIndex;
                                      final double radius = isTouched ? 35 : 28;
                                      final category = getCategory(entry.value.key);
                                      Color color = _parseColor(category.color);

                                      return PieChartSectionData(
                                        color: color,
                                        value: entry.value.value,
                                        title: '',
                                        radius: radius,
                                        badgeWidget: isTouched ? _buildChartBadge(category, color) : null,
                                        badgePositionPercentageOffset: 1.25,
                                      );
                                    }).toList(),
                                  ),
                                ),
                                // Textos en el centro
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Total',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.compactCurrency(symbol: '\$').format(totalExpenses),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'MXN',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12), // Espacio ultra-reducido
                          // Leyenda Vertical Detallada (Top 2 para máxima compacidad)
                          ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _showAllCategories ? sortedEntries.length : (sortedEntries.length > 2 ? 2 : sortedEntries.length),
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final entry = sortedEntries[index];
                              final category = getCategory(entry.key);
                              final percentage = (entry.value / totalExpenses) * 100;
                              final color = _parseColor(category.color);
                              final isSelected = touchedIndex == index;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    touchedIndex = isSelected ? -1 : index;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? color.withOpacity(0.12) : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10), // Estándar homologado
                                        ),
                                        child: Icon(
                                          _getIconFromString(category.icono),
                                          color: color,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category.nombre,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                color: isDark ? Colors.white : AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              '${percentage.toStringAsFixed(1)}% del total',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 10,
                                                color: isSelected ? color.withOpacity(0.8) : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            NumberFormat.simpleCurrency().format(entry.value),
                                            style: GoogleFonts.montserrat(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppColors.textPrimary,
                                            ),
                                          ),
                                          if (isSelected)
                                            Container(
                                              width: 24,
                                              height: 2,
                                              margin: const EdgeInsets.only(top: 2),
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          if (sortedEntries.length > 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 6), // Espacio sutil con el último ítem
                              child: Center(
                                child: InkWell(
                                  onTap: () => setState(() => _showAllCategories = !_showAllCategories),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18), // Incrementado 2px para mejor área táctil
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _showAllCategories ? Icons.keyboard_arrow_up : Icons.more_horiz,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _showAllCategories ? 'Ocultar' : 'Ver ${sortedEntries.length - 2} más',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const _ChartLoadingSkeleton(),
                    error: (_, __) => const Text('Error al cargar categorías'),
                  );
                },
                loading: () => const _ChartLoadingSkeleton(),
                error: (_, __) => const Text('Error al cargar transacciones'),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    final periods = ['Este mes', '30 días', 'Este año'];
    final textColor = isDark ? Colors.white.withOpacity(0.9) : AppColors.textPrimary;
    final bgColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: periodFilter,
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: textColor),
          elevation: 16,
          dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                periodFilter = newValue;
                touchedIndex = -1; // Reset selection
                _showAllCategories = false; // Reset view
              });
            }
          },
          items: periods.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _parseColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return AppColors.primary;
    try {
      String colorStr = colorHex.replaceAll('#', '');
      if (colorStr.length == 6) colorStr = 'FF$colorStr';
      return Color(int.parse(colorStr, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'shopping_cart': return Icons.shopping_cart;
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'home': return Icons.home;
      case 'credit_card': return Icons.credit_card;
      case 'savings': return Icons.savings;
      case 'more_horiz': return Icons.more_horiz;
      case 'fastfood': return Icons.fastfood;
      case 'electric_bolt': return Icons.electric_bolt;
      case 'movie': return Icons.movie;
      case 'fitness_center': return Icons.fitness_center;
      case 'medical_services': return Icons.medical_services;
      case 'school': return Icons.school;
      case 'flight': return Icons.flight;
      default: return Icons.category;
    }
  }

  Widget _buildChartBadge(CategoryModel category, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getIconFromString(category.icono),
        color: Colors.white,
        size: 14,
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
                  fontSize: AppColors.bodySmall,
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
                    fontSize: AppColors.bodySmall,
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
          padding: EdgeInsets.all(AppColors.cardPadding),
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
                            fontSize: AppColors.bodySmall,
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10), // Squircle homologado
                          ),
                          child: const Icon(
                            Icons.money_off_rounded,
                            color: Colors.orange,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            debt.nombre,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatter.format(debt.montoRestante),
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              debt.fechaVencimiento != null 
                                  ? 'Vence: ${DateFormat('dd MMM').format(debt.fechaVencimiento!)}'
                                  : _formatDebtType(debt.tipo),
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Botón de pago compacto SM
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => showTransactionFormSheet(
                              context,
                              transaction: TransactionModel(
                                id: '', // Nueva
                                userId: '',
                                tipo: 'pago_deuda',
                                monto: 0,
                                fecha: DateTime.now(),
                                estado: 'completa',
                                cuentaOrigenId: '', // Requerido en el form
                                deudaId: debt.id,
                                createdAt: DateTime.now(),
                                isRecurring: false,
                                autoComplete: false,
                                weekendAdjustment: false,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                size: 14,
                                color: Colors.orange,
                              ),
                            ),
                          ),
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
      Color color = Colors.grey[400]!;
      IconData icon = Icons.description_outlined;

      if (tx.tipo == 'pago_deuda') {
        color = Colors.orange;
        icon = Icons.money_off_rounded;
      } else if (tx.tipo == 'meta_aporte') {
        color = Colors.teal;
        icon = Icons.flag_rounded;
      }

      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10), // Homologado: Squircle Premium
        ),
        child: Icon(
          icon,
          color: color,
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
              color: backgroundColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10), // Homologado: Squircle Premium
            ),
            child: Icon(iconData, color: backgroundColor, size: 16),
          );
        } catch (e) {
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[400]!.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.description_outlined,
              color: Colors.grey[400],
              size: 16,
            ),
          );
        }
      },
      loading: () => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
      error: (_, __) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.error_outline,
          color: Colors.red,
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

class _ChartLoadingSkeleton extends StatelessWidget {
  const _ChartLoadingSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
