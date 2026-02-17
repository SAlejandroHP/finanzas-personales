import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/app_toast.dart';
import 'package:finanzas/features/debts/models/debt_model.dart';
import '../providers/debts_provider.dart';
import '../widgets/debt_form_sheet.dart';

class DebtsListScreen extends ConsumerWidget {
  const DebtsListScreen({Key? key}) : super(key: key);

  void _showDebtForm(BuildContext context, {DebtModel? debt}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DebtFormSheet(debt: debt),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final debtsAsync = ref.watch(debtsListProvider);
    final currencyFormatter = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mis Deudas',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, 
                color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: debtsAsync.when(
        data: (debts) {
          if (debts.isEmpty) {
            return _buildEmptyState(isDark);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: debts.length,
            itemBuilder: (context, index) {
              final debt = debts[index];
              return _buildDebtCard(context, ref, debt, currencyFormatter, isDark);
            },
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDebtForm(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_score_outlined,
            size: 80,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes deudas registradas',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para agregar una nueva deuda',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: isDark ? Colors.white24 : Colors.grey[400],
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
    
    return GestureDetector(
      onTap: () => _showDebtForm(context, debt: debt),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.nombre,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _formatTipo(debt.tipo),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(debt.estado).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        debt.estado.toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _getEstadoColor(debt.estado),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () => _confirmDelete(context, ref, debt),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resta por pagar',
                      style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      formatter.format(debt.montoRestante),
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Monto total',
                      style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      formatter.format(debt.montoTotal),
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                valueColor: AlwaysStoppedAnimation<Color>(
                  debt.estado == 'pagada' ? Colors.green : AppColors.primary,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso: ${(progress * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                if (debt.fechaVencimiento != null)
                  Text(
                    'Vence: ${DateFormat('dd MMM').format(debt.fechaVencimiento!)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: debt.fechaVencimiento!.isBefore(DateTime.now()) && debt.estado != 'pagada' 
                          ? Colors.red 
                          : Colors.grey,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
}
