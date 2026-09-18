import 'package:flutter/material.dart';
import 'package:finanzas/features/dashboard/presentation/widgets/smart_input_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../accounts/models/account_model.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../../categories/models/category_model.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/bank_logo.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../debts/models/debt_model.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../transactions/presentation/widgets/transaction_form_sheet.dart';
import '../../../../core/services/finance_service.dart';
import '../../../../core/widgets/app_toast.dart';

/// Pantalla del dashboard que muestra un resumen financiero.
/// Permite navegar a cuentas, categorías y transacciones.

class SelectedDateNotifier extends Notifier<DateTime> {
  bool _initialized = false;

  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }

  void initializeWithTransactions(List<TransactionModel> transactions) {
    if (_initialized) return;
    _initialized = true;

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayHasTx = transactions.any((tx) => 
        DateTime(tx.fecha.year, tx.fecha.month, tx.fecha.day).isAtSameMomentAs(today));

    if (!todayHasTx) {
      final futurePendingTxs = transactions
          .where((tx) => 
              tx.estado == 'pendiente' && 
              DateTime(tx.fecha.year, tx.fecha.month, tx.fecha.day).isAfter(today))
          .toList();
      
      if (futurePendingTxs.isNotEmpty) {
        futurePendingTxs.sort((a, b) => a.fecha.compareTo(b.fecha));
        final nextTx = futurePendingTxs.first;
        final nextDate = DateTime(nextTx.fecha.year, nextTx.fecha.month, nextTx.fecha.day);
        
        Future.microtask(() => state = nextDate);
      }
    }
  }
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(() {
  return SelectedDateNotifier();
});

final transactionsForSelectedDateProvider = Provider<List<TransactionModel>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final allTransactions = ref.watch(transactionsListProvider).value ?? [];
  
  return allTransactions.where((tx) {
    return tx.fecha.year == selectedDate.year &&
           tx.fecha.month == selectedDate.month &&
           tx.fecha.day == selectedDate.day;
  }).toList()
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ScrollController _calendarScrollController = ScrollController();
  DateTime? _lastCenteredDate;
  int touchedIndex = -1;
  String periodFilter = 'Este mes';
  bool _showAllCategories = false;
  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundColor;
    final totalBalance = ref.watch(totalBalanceProvider);
    final realAvailable = ref.watch(realAvailableBalanceProvider);
    final accounts = ref.watch(accountsWithBalanceProvider);
    final pendingTransactions = ref.watch(pendingTransactionsProvider);
    
    final allTransactionsAsync = ref.watch(transactionsListProvider);
    double paidIncome = 0.0;
    double paidExpenses = 0.0;
    
    allTransactionsAsync.whenData((txs) {
      final now = DateTime.now();
      for (final tx in txs) {
        if (tx.fecha.month == now.month && tx.fecha.year == now.year && tx.estado == 'completada') {
          if (tx.tipo == 'ingreso') paidIncome += tx.monto;
          if (tx.tipo == 'gasto') paidExpenses += tx.monto;
        }
      }
    });
    
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surface;

    // Inicializar el calendario con el día más cercano de transacciones
    ref.listen(transactionsListProvider, (previous, next) {
      next.whenData((transactions) {
        ref.read(selectedDateProvider.notifier).initializeWithTransactions(transactions);
      });
    });


    // Formateador de moneda estándar
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_MX',
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
        child: Column(
          children: [
            // Header Fixed (Fuera del scroll)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppColors.pagePadding, 10, AppColors.pagePadding, 0),
              child: _buildHeader(context, ref),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Refresca los proveedores principales del dashboard
                  ref.read(financeServiceProvider).refreshAll();
                  // Pequeño delay artificial para que el usuario sienta la actualización
                  await Future.delayed(const Duration(milliseconds: 1200));
                },
                displacement: 20,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(), // Necesario para RefreshIndicator
                  padding: const EdgeInsets.fromLTRB(
                    AppColors.pagePadding, 
                    0, 
                    AppColors.pagePadding, 
                    AppColors.pagePadding
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPendingInvitations(context, ref, isDark),
                      _buildPendingGoalInvitations(context, ref, isDark),
                      const SizedBox(height: 12),
                      
                      _buildBalanceSummaryCard(
                        context,
                        totalBalance,
                        realAvailable,
                        paidIncome,
                        paidExpenses,
                        mxnFormatter,
                        currencyFormatter,
                        cardColor,
                        isDark,
                      ),

                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SmartInputBar(),
                      ),
                      const SizedBox(height: 8),
                      _buildCalendarAndTransactions(
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
          ],
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
                  fontSize: AppColors.titleLarge, // Made big like a title
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
    return InkWell(
      onTap: () {
        final DateTime now = DateTime.now();
        showDialog(
          context: context,
          builder: (context) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? ColorScheme.dark(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: const Color(0xFF1E1E1E), // Slate Dark
                        onSurface: Colors.white,
                      )
                    : ColorScheme.light(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: Colors.white,
                        onSurface: AppColors.textPrimary,
                      ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                  ),
                ),
              ),
              child: Dialog(
                backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'CALENDARIO',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CalendarDatePicker(
                      initialDate: now,
                      firstDate: now.subtract(const Duration(days: 365 * 2)),
                      lastDate: now.add(const Duration(days: 365 * 2)),
                      onDateChanged: (_) {}, // No hace nada por ahora
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'CERRAR',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      borderRadius: BorderRadius.circular(AppColors.radiusLarge),
      child: Container(
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
      ),
    );
  }

  
Widget _buildPendingInvitations(BuildContext context, WidgetRef ref, bool isDark) {
    final invitationsAsync = ref.watch(pendingInvitationsProvider);

    return invitationsAsync.maybeWhen(
      data: (invitations) {
        if (invitations.isEmpty) return SizedBox.shrink(key: UniqueKey());

        return Column(
          children: invitations.map((inv) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Fondo decorativo
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.people_alt_rounded,
                        size: 100,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondary,
                            AppColors.secondary.withBlue(200).withRed(150),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invitación recibida',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${inv.nombre} • \$${NumberFormat.decimalPattern().format(inv.montoTotal)}',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await ref.read(debtsNotifierProvider.notifier).acceptInvitation(inv);
                                    if (context.mounted) {
                                      showAppToast(context, message: 'Deuda aceptada y vinculada correctamente', type: ToastType.success);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAppToast(context, message: 'Error: $e', type: ToastType.error);
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.secondary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Aceptar',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    await ref.read(debtsNotifierProvider.notifier).rejectInvitation(inv);
                                    if (context.mounted) {
                                      showAppToast(context, message: 'Invitación rechazada', type: ToastType.info);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAppToast(context, message: 'Error: $e', type: ToastType.error);
                                    }
                                  }
                                },
                                child: Text(
                                  'Rechazar',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      orElse: () => SizedBox.shrink(key: UniqueKey()),
    );
  }

  Widget _buildPendingGoalInvitations(BuildContext context, WidgetRef ref, bool isDark) {
    final goalsInvitationsAsync = ref.watch(pendingGoalsInvitationsProvider);

    return goalsInvitationsAsync.maybeWhen(
      data: (invitations) {
        if (invitations.isEmpty) return SizedBox.shrink(key: UniqueKey());

        return Column(
          children: invitations.map((goal) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Fondo decorativo
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.track_changes_rounded,
                        size: 100,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            Color(0xFF0D9488), // Teal premium
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Meta compartida',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Invitación para "${goal.title}"',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await ref.read(goalsNotifierProvider.notifier).acceptInvitation(goal);
                                    if (context.mounted) {
                                      showAppToast(context, message: 'Meta aceptada correctamente', type: ToastType.success);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAppToast(context, message: 'Error: $e', type: ToastType.error);
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Aceptar',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  try {
                                    await ref.read(goalsNotifierProvider.notifier).rejectInvitation(goal);
                                    if (context.mounted) {
                                      showAppToast(context, message: 'Invitación rechazada', type: ToastType.info);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showAppToast(context, message: 'Error: $e', type: ToastType.error);
                                    }
                                  }
                                },
                                child: Text(
                                  'Rechazar',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      orElse: () => SizedBox.shrink(key: UniqueKey()),
    );
  }

  Widget _buildBalanceSummaryCard(
    BuildContext context,
    double balance,
    double realAvailable,
    double incomes,
    double expenses,
    NumberFormat balanceFormatter,
    NumberFormat flowFormatter,
    Color cardColor,
    bool isDark,
  ) {
    final Color cardBackground = isDark ? AppColors.surfaceDark : AppColors.primary;
    
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: [
                cardBackground,
                isDark ? cardBackground.withOpacity(0.8) : const Color(0xFF0D47A1), // Deep blue for light mode
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

          ),
          child: Stack(
            children: [
              // Decorative background elements for premium feel
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -40,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BALANCE TOTAL',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 2.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        balanceFormatter.format(balance),
                        style: GoogleFonts.montserrat(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -26),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFlowItem('Ingresos', incomes, const Color(0xFF10B981), Icons.arrow_upward_rounded, isDark),
              const SizedBox(width: 12),
              _buildFlowItem('Gastos', expenses, const Color(0xFFEF4444), Icons.arrow_downward_rounded, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlowItem(
    String label,
    double amount,
    Color accentColor,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.03),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white54 : Colors.black45,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(amount),
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          color: color,
          borderRadius: BorderRadius.circular(8), // Homologado: Squircle Premium
        ),
        child: Icon(
          icon,
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
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8), // Homologado: Squircle Premium
            ),
            child: Icon(iconData, color: Colors.white, size: 16),
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

  Widget _buildCalendarAndTransactions(
    BuildContext context,
    WidgetRef ref,
    NumberFormat formatter,
    bool isDark,
    Color cardColor,
  ) {
    final selectedDate = ref.watch(selectedDateProvider);
    final transactions = ref.watch(transactionsForSelectedDateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transacciones',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                (() {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final selectedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                  
                  String dayStr = DateFormat('d', 'es_MX').format(selectedDate);
                  String monthStr = DateFormat('MMMM', 'es_MX').format(selectedDate);
                  monthStr = monthStr[0].toUpperCase() + monthStr.substring(1);
                  
                  if (selectedDay.isAtSameMomentAs(today)) {
                    return 'Hoy, $dayStr $monthStr';
                  } else {
                    String weekdayStr = DateFormat('EEEE', 'es_MX').format(selectedDate);
                    weekdayStr = weekdayStr[0].toUpperCase() + weekdayStr.substring(1);
                    return '$weekdayStr $dayStr, $monthStr';
                  }
                })(),
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildHorizontalCalendar(context, ref, selectedDate, isDark, cardColor),
        const SizedBox(height: 16),
        _buildTransactionsList(context, ref, transactions, formatter, isDark, cardColor),
      ],
    );
  }

  Widget _buildHorizontalCalendar(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
    bool isDark,
    Color cardColor,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(45, (index) => today.subtract(const Duration(days: 15)).add(Duration(days: index)));

    final initialIndex = dates.indexWhere((d) => d.year == selectedDate.year && d.month == selectedDate.month && d.day == selectedDate.day);
    
    if (_lastCenteredDate != selectedDate && initialIndex != -1) {
      _lastCenteredDate = selectedDate;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_calendarScrollController.hasClients) {
          final screenWidth = MediaQuery.of(context).size.width;
          final itemWidth = 63.0; // 55 width + 8 margin
          final offset = (initialIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2) + 16;
          _calendarScrollController.animateTo(
            offset.clamp(0.0, _calendarScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }


    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: _calendarScrollController,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = date.year == selectedDate.year &&
                             date.month == selectedDate.month &&
                             date.day == selectedDate.day;
          
          final isToday = date.isAtSameMomentAs(today);

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).setDate(date);
            },
            child: Container(
              width: 55,
              margin: EdgeInsets.only(
                left: index == 0 ? 16 : 8,
                right: index == dates.length - 1 ? 16 : 0,
              ),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected 
                      ? Colors.transparent 
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E', 'es_MX').format(date).toUpperCase().replaceAll('.', ''),
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                          ? Colors.white 
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected 
                          ? Colors.white 
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    WidgetRef ref,
    List<TransactionModel> transactions,
    NumberFormat formatter,
    bool isDark,
    Color cardColor,
  ) {
    if (transactions.isEmpty) {
      final selectedDate = ref.watch(selectedDateProvider);
      final allTxs = ref.watch(transactionsListProvider).value ?? [];
      
      TransactionModel? nextTx;
      
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      
      final futureTxs = allTxs.where((tx) {
        final txDate = DateTime(tx.fecha.year, tx.fecha.month, tx.fecha.day);
        return tx.estado == 'pendiente' && txDate.isAfter(selectedDate);
      }).toList();
      
      if (futureTxs.isNotEmpty) {
        futureTxs.sort((a, b) => a.fecha.compareTo(b.fecha));
        nextTx = futureTxs.first;
      }
      
      String message = 'Sin movimientos este día';
      String? subMessage;
      
      if (nextTx != null) {
        final dateStr = DateFormat('dd MMM', 'es_MX').format(nextTx.fecha);
        message = 'Todo libre por ahora';
        subMessage = 'Tu próximo compromiso es el $dateStr';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              Icon(
                nextTx != null ? Icons.coffee_rounded : Icons.event_available_outlined,
                size: 48,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.montserrat(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subMessage != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).setDate(nextTx!.fecha);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      subMessage,
                      style: GoogleFonts.montserrat(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final categoriesAsync = ref.watch(categoriesListProvider);
    final categories = categoriesAsync.value ?? [];
    
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final accounts = accountsAsync.value ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: transactions.map((tx) {
          final isIngreso = tx.tipo == 'ingreso';
          
          String categoryName = isIngreso ? 'Ingreso' : 'Gasto';
          if (tx.categoriaId != null) {
            try {
              categoryName = categories.firstWhere((c) => c.id == tx.categoriaId).nombre;
            } catch (_) {}
          }
          
          String accountName = 'Efectivo';
          if (tx.cuentaOrigenId != null) {
            try {
              accountName = accounts.firstWhere((a) => a.id == tx.cuentaOrigenId).nombre;
            } catch (_) {}
          }
          
          String title = (tx.descripcion != null && tx.descripcion!.trim().isNotEmpty) ? tx.descripcion! : categoryName;
          String subtitle = '$categoryName • $accountName';
          if (title == categoryName) {
            subtitle = accountName;
          }
          final color = isIngreso ? Colors.green : Colors.red;
          final icon = isIngreso ? Icons.arrow_downward : Icons.arrow_upward;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  (isIngreso ? "+" : "-") + formatter.format(tx.monto),
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (tx.estado == 'pendiente') ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirmar pago'),
                          content: const Text('¿Marcar como pagado?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final repo = ref.read(transactionsRepositoryProvider);
                        final updated = tx.copyWith(estado: 'completada');
                        await repo.updateTransaction(updated);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isIngreso ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isIngreso ? 'COBRAR' : 'PAGAR',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isIngreso ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

}

