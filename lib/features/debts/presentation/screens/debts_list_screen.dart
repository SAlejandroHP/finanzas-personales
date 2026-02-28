import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';
import 'package:finanzas/features/auth/presentation/providers/auth_provider.dart';
import '../providers/debts_provider.dart';
import '../widgets/debt_form_sheet.dart';

// Provider local para filtro de estado
final debtFilterProvider = StateProvider<String>((ref) => 'todas');

class DebtsListScreen extends ConsumerWidget {
  const DebtsListScreen({Key? key}) : super(key: key);

  void _showDebtForm(BuildContext context, {DebtModel? debt}) {
    showDebtFormSheet(context, debt: debt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtsAsync = ref.watch(debtsListProvider);
    final currentFilter = ref.watch(debtFilterProvider);
    final currencyFormatter = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundColor,
      body: Column(
        children: [
          // Header Fijo Moderno (Premium)
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
                        'Deudas',
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
                    onTap: () => _showDebtForm(context),
                    icon: Icons.add_rounded,
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: debtsAsync.when(
              data: (debts) {
                if (debts.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                // Filtrar según el estado
                final filteredDebts = currentFilter == 'todas'
                    ? debts
                    : debts.where((d) => d.estado == currentFilter).toList();

                // Calcular totales para el summary
                final totalDebt = debts.fold<double>(0.0, (s, d) => s + d.montoTotal);
                final totalRemaining = debts.fold<double>(0.0, (s, d) => s + d.montoRestante);

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(debtsListProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildSummaryHeader(context, totalDebt, totalRemaining, isDark),
                      const SizedBox(height: 20),
                      _buildStatusTabs(ref, currentFilter, isDark),
                      const SizedBox(height: 16),
                      if (filteredDebts.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'Sin deudas "${currentFilter}"',
                              style: GoogleFonts.montserrat(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...filteredDebts.map((debt) => 
                          _buildDebtCard(context, ref, debt, currencyFormatter, isDark)
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: LoadingIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, double total, double remaining, bool isDark) {
    final paid = total - remaining;
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 1.0;
    final currencyFormatter = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo Pendiente',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              Icon(Icons.credit_card_rounded, color: Colors.white.withOpacity(0.4), size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(remaining),
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          // Mini barra de progreso general
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryMiniDetail('Total original', currencyFormatter.format(total)),
              _buildSummaryMiniDetail('Pagado', currencyFormatter.format(paid)),
              _buildSummaryMiniDetail('Progreso', '${(progress * 100).toInt()}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMiniDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTabs(WidgetRef ref, String currentFilter, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTab(ref, 'todas', 'Cualquiera', currentFilter == 'todas', isDark),
          _buildTab(ref, 'activa', 'Activas', currentFilter == 'activa', isDark),
          _buildTab(ref, 'pagada', 'Pagadas', currentFilter == 'pagada', isDark),
          _buildTab(ref, 'vencida', 'Vencidas', currentFilter == 'vencida', isDark),
        ],
      ),
    );
  }

  Widget _buildTab(WidgetRef ref, String filter, String label, bool isActive, bool isDark) {
    return GestureDetector(
      onTap: () => ref.read(debtFilterProvider.notifier).state = filter,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive 
              ? AppColors.primary.withOpacity(0.15) 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: isActive ? AppColors.primary : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.credit_score_rounded,
              size: 48,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin deudas registradas',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Toca el botón + en la esquina superior para agregar una nueva deuda y llevar el control.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(
    BuildContext context, 
    WidgetRef ref, 
    DebtModel debt, 
    NumberFormat formatter, 
    bool isDark
  ) {
    final progress = debt.montoTotal > 0 
        ? (1 - (debt.montoRestante / debt.montoTotal)).clamp(0.0, 1.0) 
        : 1.0;
    
    // Color según estado
    final estadoColor = _getEstadoColor(debt.estado);

    final currentUser = ref.watch(currentUserProvider).value;
    final currentUserId = currentUser?.id;

    // Identificar si soy el "Invitado" (Lectura únicamente)
    // En el modelo de Registro Único, soy invitado si la deuda está compartida Y NO soy el dueño (user_id)
    final isGuest = debt.isShared && debt.estadoInvitacion == 'accepted' && debt.userId != currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono premium squircle
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getTipoIcon(debt.tipo),
                  color: estadoColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.nombre,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      _formatTipo(debt.tipo),
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    if (debt.isShared) ...[
                      const SizedBox(height: 4),
                      _buildInvitationBadge(debt.estadoInvitacion, isDark),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(debt.montoRestante),
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Por pagar',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      color: estadoColor.withOpacity(0.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Barra de progreso estilizada
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                valueColor: AlwaysStoppedAnimation<Color>(
                  debt.estado == 'pagada' ? Colors.green : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo: ${formatter.format(debt.montoRestante)} • Total: ${formatter.format(debt.montoTotal)}',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                'Pagado: ${(progress * 100).toInt()}%',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              if (debt.fechaVencimiento != null)
                Text(
                  'Vence ${DateFormat('d MMM').format(debt.fechaVencimiento!)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: debt.fechaVencimiento!.isBefore(DateTime.now()) && debt.estado != 'pagada' 
                        ? Colors.red 
                        : Colors.grey[600],
                  ),
                ),
            ],
          ),
          if (!isGuest) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _confirmDelete(context, ref, debt),
                        icon: Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red[300]),
                        label: Text(
                          'Eliminar',
                          style: GoogleFonts.montserrat(
                            fontSize: 11, 
                            fontWeight: FontWeight.w700,
                            color: Colors.red[300],
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      if (debt.isShared)
                        TextButton.icon(
                          onPressed: () => _confirmUnlink(context, ref, debt),
                          icon: const Icon(Icons.link_off_rounded, size: 14, color: Colors.orange),
                          label: Text(
                            'Desvincular',
                            style: GoogleFonts.montserrat(
                              fontSize: 11, 
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Editar Deuda',
                  icon: Icons.edit_rounded,
                  onPressed: () => _showDebtForm(context, debt: debt),
                  variant: 'primary',
                  size: 'small',
                  height: 32,
                ),
              ],
            ),
          ],
          if (isGuest) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   const Icon(Icons.info_outline_rounded, size: 14, color: Colors.blue),
                   const SizedBox(width: 8),
                   Text(
                     'Modo lectura: Solo el dueño puede editar',
                     style: GoogleFonts.montserrat(
                       fontSize: 10,
                       fontWeight: FontWeight.w600,
                       color: Colors.blue[700],
                     ),
                   ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getTipoIcon(String tipo) {
    switch (tipo) {
      case 'prestamo_personal': return Icons.person_outline_rounded;
      case 'prestamo_bancario': return Icons.account_balance_rounded;
      case 'servicio': return Icons.receipt_long_rounded;
      default: return Icons.credit_card_rounded;
    }
  }

  String _formatTipo(String tipo) {
    switch (tipo) {
      case 'prestamo_personal': return 'Préstamo Personal';
      case 'prestamo_bancario': return 'Préstamo Bancario';
      case 'servicio': return 'Servicio';
      default: return 'Otro';
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'activa': return Colors.orange;
      case 'pagada': return Colors.green;
      case 'vencida': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DebtModel debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar deuda?'),
        content: Text('Esto eliminará el registro de la deuda "${debt.nombre}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(debtsNotifierProvider.notifier).deleteDebt(debt.id);
              if (context.mounted) {
                showAppToast(context, message: 'Deuda eliminada', type: ToastType.success);
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmUnlink(BuildContext context, WidgetRef ref, DebtModel debt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Desvincular deuda?'),
        content: const Text(
          'Esto dejará de sincronizar los pagos con el otro usuario. '
          'Ambos conservarán su propio registro de forma independiente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(debtsNotifierProvider.notifier).unlinkDebt(debt.id);
              if (context.mounted) {
                showAppToast(context, message: 'Deuda desvinculada', type: ToastType.success);
              }
            },
            child: const Text('Desvincular', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationBadge(String estado, bool isDark) {
    Color color;
    String text;
    IconData icon;

    switch (estado) {
      case 'accepted':
        color = Colors.blue;
        text = 'Vinculada';
        icon = Icons.link_rounded;
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rechazada';
        icon = Icons.link_off_rounded;
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Pendiente';
        icon = Icons.hourglass_empty_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
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
    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      onPressed: onTap,
    );
  }
}
