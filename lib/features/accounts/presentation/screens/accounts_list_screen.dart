import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/accounts_provider.dart';
import '../widgets/account_card.dart';
import '../../../../core/widgets/bank_logo.dart';
import '../widgets/account_form_bottom_sheet.dart';
import '../providers/currencies_provider.dart';
import '../../models/bank_model.dart';
import '../providers/banks_provider.dart';

/// Pantalla que muestra la lista de cuentas del usuario en formato de rejilla creativa.
class AccountsListScreen extends ConsumerWidget {
  const AccountsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundColor;
    final appBarColor = isDark ? AppColors.backgroundDark : AppColors.backgroundColor;
    final accountsAsync = ref.watch(accountsWithBalanceProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Cuentas',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: AppColors.titleMedium,
            color: isDark ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: AppColors.cardElevation,
        backgroundColor: appBarColor,
        foregroundColor: isDark ? AppColors.textSecondary : AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAccountForm(context, ref),
            tooltip: 'Agregar cuenta',
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(context, accounts, isDark),
                
                // Catálogo de bancos de Belvo
                _buildBankCatalog(context, ref, isDark),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppColors.pagePadding, vertical: 8),
                  child: Text(
                    'Tus activos',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodyMedium,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppColors.pagePadding, 0, AppColors.pagePadding, 120),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppColors.contentGap,
                    mainAxisSpacing: AppColors.contentGap,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    return Consumer(
                      builder: (context, ref, child) {
                        final currencyAsync = ref.watch(currencyByIdProvider(account.monedaId));
                        final symbol = currencyAsync.asData?.value?.simbolo ?? '\$';

                        return AccountCard(
                          account: account,
                          currencySymbol: symbol,
                          onEdit: () {
                            ref.read(selectedAccountProvider.notifier).state = account;
                            _showAccountForm(context, ref);
                          },
                          onDelete: () async {
                            final confirmed = await _showDeleteDialog(context, account.nombre);
                            if (confirmed && context.mounted) {
                              _handleDelete(context, ref, account.id);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, stack) => _buildErrorState(context, ref, error.toString(), isDark),
      ),

    );
  }

  Widget _buildSummaryCard(BuildContext context, List<dynamic> accounts, bool isDark) {
    // Cálculo de Patrimonio Neto: Activos (Saldo de cuentas) - Pasivos (Deuda acumulada en TC)
    final totalBalance = accounts.fold<double>(0, (sum, acc) {
      if (acc.tipo == 'tarjeta_credito') {
        // En TC: saldoInicial es el límite, saldoActual es el disponible.
        // Deuda = Límite - Disponible. Esto resta del patrimonio.
        final debt = acc.saldoInicial - acc.saldoActual;
        return sum - debt;
      } else {
        // En cuentas de activos, sumamos el saldo actual.
        return sum + acc.saldoActual;
      }
    });
    
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patrimonio Total Estimado',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodySmall,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormatter.format(totalBalance),
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.titleLarge,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
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
              Icons.account_balance_wallet_rounded,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin cuentas',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: AppColors.titleSmall,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comienza a registrar tus cuentas',
            style: GoogleFonts.montserrat(
              color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.6),
              fontSize: AppColors.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            'Error al cargar cuentas',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: AppColors.bodyLarge),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(color: Colors.grey, fontSize: AppColors.bodySmall),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.invalidate(accountsWithBalanceProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showAccountForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const AccountFormBottomSheet(),
    ).then((_) {
      ref.read(selectedAccountProvider.notifier).state = null;
    });
  }

  Future<bool> _showDeleteDialog(BuildContext context, String accountName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text('¿Está seguro que desea eliminar la cuenta "$accountName"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildBankCatalog(BuildContext context, WidgetRef ref, bool isDark) {
    final banksAsync = ref.watch(banksProvider('MX'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Instituciones Disponibles',
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.bodyMedium,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Belvo',
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.bodySmall,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 90,
          child: banksAsync.when(
            data: (banks) {
              if (banks.isEmpty) return const SizedBox.shrink();
              
              // Mostrar solo los primeros 10 bancos como "populares"
              // Mostrar más instituciones para incluir Fintechs populares
              final popularBanks = banks.take(25).toList();
              
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: popularBanks.length,
                itemBuilder: (context, index) {
                  final bank = popularBanks[index];
                  return _buildBankItem(context, ref, bank, isDark);
                },
              );
            },
            loading: () => ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) => _buildBankSkeleton(isDark),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBankItem(BuildContext context, WidgetRef ref, BankModel bank, bool isDark) {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              // Preseleccionar el banco para el formulario
              ref.read(selectedBankProvider.notifier).state = bank;
              _showAccountForm(context, ref);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: BankLogo(
                  bankName: bank.displayName,
                  primaryColor: bank.primaryColor,
                  size: 32,
                ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bank.displayName.split(' ')[0], // Solo la primera palabra para que quepa
            style: GoogleFonts.montserrat(
              fontSize: AppColors.bodySmall,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBankSkeleton(bool isDark) {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 8,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(accountsNotifierProvider.notifier).deleteAccount(id);
      if (context.mounted) {
        showAppToast(context, message: 'Cuenta eliminada', type: ToastType.success);
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, message: 'Error: $e', type: ToastType.error);
      }
    }
  }
}
