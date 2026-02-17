import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/presentation/providers/recurring_warnings_provider.dart';

/// Pantalla de notificaciones con diseño premium y minimalista.
/// Sigue la estética del dashboard principal.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : AppColors.backgroundColor;
    final warnings = ref.watch(recurringWarningsProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, warnings.isNotEmpty, isDark),
            Expanded(
              child: warnings.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : _buildNotificationsList(context, ref, warnings, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool hasWarnings, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notificaciones',
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Avisos y recordatorios',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodySmall,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (hasWarnings)
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {
                  showAppToast(
                    context,
                    message: 'Notificaciones actualizadas',
                    type: ToastType.info,
                  );
                },
                icon: const Icon(Icons.done_all_rounded, size: 20, color: AppColors.primary),
                tooltip: 'Marcar leídas',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppColors.xl),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : AppColors.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Todo en orden!',
            style: GoogleFonts.montserrat(
              fontSize: AppColors.titleSmall,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'No tienes pagos pendientes o avisos por el momento.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: AppColors.bodyMedium,
                color: isDark ? Colors.white38 : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    WidgetRef ref,
    List<RecurringWarning> warnings,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: warnings.length,
      itemBuilder: (context, index) {
        final warning = warnings[index];
        return _buildNotificationCard(context, ref, warning, isDark);
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    RecurringWarning warning,
    bool isDark,
  ) {
    final isVence = warning.type == WarningType.vence;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final accentColor = isVence ? Colors.red : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
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
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        child: Stack(
          children: [
            // Línea de acento lateral
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 5,
                color: accentColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isVence ? Icons.priority_high_rounded : Icons.info_outline_rounded,
                          color: accentColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              warning.title,
                              style: GoogleFonts.montserrat(
                                fontSize: AppColors.bodySmall,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _formatDateFancy(warning.transaction.fecha),
                              style: GoogleFonts.montserrat(
                                fontSize: AppColors.bodySmall,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    warning.message,
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodyMedium,
                      color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Detalle de la transacción estilo "Mini Card"
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TRANSACCIÓN',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                warning.transaction.descripcion ?? 'Sin descripción',
                                style: GoogleFonts.montserrat(
                                  fontSize: AppColors.bodyMedium,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'MONTO',
                              style: GoogleFonts.montserrat(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(warning.transaction.monto),
                              style: GoogleFonts.montserrat(
                                fontSize: AppColors.bodyLarge,
                                fontWeight: FontWeight.w700,
                                color: isVence ? Colors.red[400] : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Botón de acción Premium
                  SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
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
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isVence 
                                  ? [Colors.red[400]!, Colors.red[700]!]
                                  : [AppColors.primary, const Color(0xFF0D9BA1)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'PAGAR AHORA',
                                  style: GoogleFonts.montserrat(
                                    fontSize: AppColors.bodySmall,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
  }

  String _formatDateFancy(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) return 'Para hoy';
    if (difference == 1) return 'Para mañana';
    if (difference == -1) return 'Venció ayer';
    if (difference < 0) return 'Venció hace ${difference.abs()} días';
    return 'En $difference días';
  }
}
