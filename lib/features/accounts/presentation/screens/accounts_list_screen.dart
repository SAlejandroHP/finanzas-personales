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
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../models/bank_model.dart';
import '../providers/banks_provider.dart';

/// Pantalla que muestra la lista de cuentas del usuario en formato de rejilla creativa.
class AccountsListScreen extends ConsumerWidget {
  const AccountsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundColor;
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final totalDebts = ref.watch(totalDebtsProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mis Cuentas',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
              ),
              onPressed: () => _showAccountForm(context, ref),
            ),
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
                _buildSummaryCard(context, totalBalance, totalDebts, isDark),
                
                // Catálogo de bancos de Belvo
                _buildBankCatalog(context, ref, isDark),

                _buildSectionHeader(context, 'Tus activos'),

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

  Widget _buildSummaryCard(BuildContext context, double totalAssets, double totalDebts, bool isDark) {
    // Patrimonio Neto = Activos - Deudas
    final netWorth = totalAssets - totalDebts;
    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppColors.pagePadding, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withRed(30).withGreen(100), // Teal vibrante
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decoración Glassmorphism
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'PATRIMONIO NETO',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormatter.format(netWorth),
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Barra inferior con Activos y Deudas (Estilo Dashboard)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildCompactIndicator(
                            'Activos',
                            currencyFormatter.format(totalAssets),
                            Colors.white,
                            Icons.arrow_upward_rounded,
                          ),
                        ),
                        Container(height: 20, width: 1, color: Colors.white.withOpacity(0.15)),
                        Expanded(
                          child: _buildCompactIndicator(
                            'Deudas',
                            currencyFormatter.format(totalDebts),
                            Colors.white.withOpacity(0.8),
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

  Widget _buildCompactIndicator(String label, String amount, Color color, IconData icon) {
    return Column(
      children: [
        Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(icon, size: 10, color: color.withOpacity(0.8)),
             const SizedBox(width: 4),
             Text(
               label.toUpperCase(),
               style: GoogleFonts.montserrat(
                 fontSize: 8,
                 fontWeight: FontWeight.w800,
                 color: color.withOpacity(0.7),
                 letterSpacing: 0.5,
               ),
             ),
           ],
        ),
        const SizedBox(height: 2),
        Text(
          amount,
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

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20), // Squircle
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sin cuentas aún',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus activos aparecerán aquí',
            style: GoogleFonts.montserrat(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(context, 'Instituciones Aliadas'),
            Padding(
              padding: const EdgeInsets.only(right: 20, top: 20),
              child: Text(
                'BELVO',
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary.withOpacity(0.3),
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 95,
          child: banksAsync.when(
            data: (banks) {
              if (banks.isEmpty) return const SizedBox.shrink();
              final popularBanks = banks.take(25).toList();
              
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: popularBanks.length,
                itemBuilder: (context, index) {
                  final bank = popularBanks[index];
                  return _buildBankItem(context, ref, bank, isDark);
                },
              );
            },
            loading: () => ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) => _buildBankSkeleton(isDark),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBankItem(BuildContext context, WidgetRef ref, BankModel bank, bool isDark) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              ref.read(selectedBankProvider.notifier).state = bank;
              _showAccountForm(context, ref);
            },
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(10), // Squircle homologado R:10
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: BankLogo(
                bankName: bank.displayName,
                primaryColor: bank.primaryColor,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bank.displayName.split(' ')[0],
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Construye el encabezado de una sección
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primary.withOpacity(0.6),
          letterSpacing: 1.5,
        ),
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
