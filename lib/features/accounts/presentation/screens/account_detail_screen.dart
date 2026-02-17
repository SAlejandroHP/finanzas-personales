import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../models/account_model.dart';
import '../providers/accounts_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../../transactions/presentation/widgets/transaction_form_sheet.dart';
import '../../../../core/widgets/app_toast.dart';

class AccountDetailScreen extends ConsumerWidget {
  final String accountId;

  const AccountDetailScreen({
    Key? key,
    required this.accountId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final transactionsAsync = ref.watch(transactionsByAccountProvider(accountId));
    
    return accountsAsync.when(
      data: (accounts) {
        final account = accounts.firstWhere((a) => a.id == accountId);
        final isTC = account.tipo == 'tarjeta_credito';
        
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              account.nombre,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white70 : Colors.grey),
                onPressed: () {
                  // TODO: Navegar a edición
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceHeader(ref, account, isDark),
                const SizedBox(height: 24),
                
                if (isTC) ...[
                  _buildCreditCardInfo(context, ref, account, isDark),
                  const SizedBox(height: 24),
                  _buildEducationalTips(account, isDark),
                  const SizedBox(height: 24),
                ],
                
                _buildTransactionsSection(context, ref, transactionsAsync, isDark),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, __) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildBalanceHeader(WidgetRef ref, AccountModel account, bool isDark) {
    final formatter = NumberFormat.currency(symbol: '\$ ');
    final isTC = account.tipo == 'tarjeta_credito';
    
    // Para tarjetas de crédito, obtener la deuda asociada desde la tabla deudas
    final deudaActual = isTC 
        ? account.saldoInicial - account.saldoActual  // Deuda = límite - disponible
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTC 
              ? [const Color(0xFF2C3E50), const Color(0xFF000000)]
              : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isTC ? Colors.black : AppColors.primary).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTC ? 'CRÉDITO DISPONIBLE' : 'SALDO ACTUAL',
            style: GoogleFonts.montserrat(
              fontSize: AppColors.bodySmall,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(account.saldoActual),
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (isTC) ...[
             const SizedBox(height: 16),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 _buildMiniInfo('Límite', formatter.format(account.saldoInicial)),
                 _buildMiniInfo('Deuda', formatter.format(deudaActual)),
               ],
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: AppColors.bodySmall,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: AppColors.bodyMedium,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditCardInfo(BuildContext context, WidgetRef ref, AccountModel account, bool isDark) {
    // Detalle de la tarjeta de crédito
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Detalle de la Tarjeta',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: AppColors.bodyMedium,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Fecha de corte', 'Día 15 de cada mes', isDark),
          const Divider(height: 24),
          _buildDetailRow('Fecha límite pago', 'Día 05 del mes sig.', isDark),
          const Divider(height: 24),
          _buildDetailRow('Estado', 'Al corriente', isDark),
          const SizedBox(height: 20),
          AppButton(
            label: 'Ver detalles avanzados',
            variant: 'outlined',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => _buildAdvancedDetailsSheet(account, isDark),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedDetailsSheet(AccountModel account, bool isDark) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Análisis Avanzado',
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.titleMedium,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildAdvancedDetailItem(
                'Tasa de Interés Anual (estimada)',
                '45.0%',
                'Esta es una tasa promedio para este tipo de productos. El pago puntual evita este cargo.',
                Icons.percent,
              ),
              const SizedBox(height: 16),
              _buildAdvancedDetailItem(
                'Uso de línea de crédito',
                '${((account.saldoInicial - account.saldoActual) / account.saldoInicial * 100).toStringAsFixed(1)}%',
                'Mantener el uso por debajo del 30% ayuda a mejorar tu historial crediticio.',
                Icons.pie_chart_outline,
              ),
              const SizedBox(height: 24),
              _buildEducationalTips(account, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdvancedDetailItem(String title, String value, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium, fontWeight: FontWeight.w600)),
                  Text(value, style: GoogleFonts.montserrat(fontSize: AppColors.bodyMedium, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(description, style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: AppColors.bodySmall,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: AppColors.bodySmall,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEducationalTips(AccountModel account, bool isDark) {
    final formatter = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
    final limit30 = account.saldoInicial * 0.3;
    final formattedLimit = formatter.format(limit30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIPS FINANCIEROS',
          style: GoogleFonts.montserrat(
            fontSize: AppColors.bodySmall,
            fontWeight: FontWeight.w800,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        _buildTipCard(
          'Evita pagar solo el mínimo',
          'Pagar solo el mínimo genera intereses que pueden duplicar tu deuda en poco tiempo.',
          Icons.trending_down,
          isDark,
        ),
        const SizedBox(height: 12),
        _buildTipCard(
          'Usa menos de $formattedLimit',
          'Para mantener un score crediticio excelente, intenta no superar el 30% de tu límite (\$${formatter.format(account.saldoInicial)}).',
          Icons.speed,
          isDark,
        ),
      ],
    );
  }

  Widget _buildTipCard(String title, String content, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: AppColors.bodySmall,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodySmall,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection(BuildContext context, WidgetRef ref, AsyncValue<List<TransactionModel>> transactionsAsync, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Movimientos recientes',
            style: GoogleFonts.montserrat(
              fontSize: AppColors.titleSmall,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'No hay movimientos para mostrar', 
                        style: GoogleFonts.montserrat(color: Colors.grey, fontSize: AppColors.bodyMedium),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length > 20 ? 20 : transactions.length, // Limitado para performance en detalle
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return TransactionTile(
                  transaction: transaction,
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
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Center(child: Text('Error: $e')),
        ),
        const SizedBox(height: 100), // Espacio extra al final
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar transacción'),
        content: const Text('¿Estás seguro de que deseas eliminar esta transacción?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(transactionsNotifierProvider.notifier).deleteTransaction(transactionId);
                if (context.mounted) {
                  Navigator.pop(context);
                  showAppToast(context, message: 'Transacción eliminada', type: ToastType.success);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  showAppToast(context, message: 'Error al eliminar: $e', type: ToastType.error);
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
