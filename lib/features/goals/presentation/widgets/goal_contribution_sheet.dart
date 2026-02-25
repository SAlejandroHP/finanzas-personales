import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/finance_service.dart';
import '../../../accounts/presentation/providers/accounts_provider.dart';
import '../../models/goal_model.dart';
import '../../../accounts/models/account_model.dart';

class GoalContributionSheet extends ConsumerStatefulWidget {
  final GoalModel goal;

  const GoalContributionSheet({Key? key, required this.goal}) : super(key: key);

  @override
  ConsumerState<GoalContributionSheet> createState() => _GoalContributionSheetState();
}

class _GoalContributionSheetState extends ConsumerState<GoalContributionSheet> {
  final _amountController = TextEditingController();
  AccountModel? _selectedAccount;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Sugerencia de ahorro mensual si existe
    if (widget.goal.suggestedMonthlySavings != null && !widget.goal.isCompleted) {
      // Formatear sin .0 si es entero
      final suggested = widget.goal.suggestedMonthlySavings!;
      _amountController.text = suggested % 1 == 0 ? suggested.toInt().toString() : suggested.toString();
    }
  }

  void _saveContribution() async {
    if (_amountController.text.isEmpty || _selectedAccount == null) return;
    
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(financeServiceProvider).processGoalContribution(
        goalId: widget.goal.id,
        amount: amount,
        accountId: _selectedAccount!.id,
        description: 'Aporte para meta: ${widget.goal.title}',
        fecha: _selectedDate,
      );
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Manejo de error
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsWithBalanceProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencyFormatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0);

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12, 
        bottom: 20 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, 
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aportar a Meta',
              style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Cuánto deseas ahorrar hoy para "${widget.goal.title}"?',
              style: GoogleFonts.montserrat(fontSize: 14, color: AppColors.description),
            ),
            const SizedBox(height: 24),
            
            // Input de Monto
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.primary.withOpacity(0.3)),
              ),
            ),
            const SizedBox(height: 24),

            // Selección de Cuenta Origen
            Text(
              '¿De qué cuenta proviene el dinero?',
              style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.description),
            ),
            const SizedBox(height: 8),
            accountsAsync.when(
              data: (accounts) {
                final filteredAccounts = accounts.where((a) => a.tipo != 'tarjeta_credito').toList();
                return Container(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredAccounts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final acc = filteredAccounts[index];
                      final isSelected = _selectedAccount?.id == acc.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAccount = acc),
                        child: Container(
                          width: 130,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getAccountIcon(acc.tipo), size: 24, color: isSelected ? AppColors.primary : AppColors.description),
                              const SizedBox(height: 4),
                              Text(
                                acc.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                currencyFormatter.format(acc.saldoActual),
                                style: GoogleFonts.montserrat(fontSize: 10, color: AppColors.description),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            
            const SizedBox(height: 24),
            
            // Botón Guardar
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveContribution,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'CONFIRMAR APORTE',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.1),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type) {
      case 'efectivo': return Icons.money;
      case 'ahorro': return Icons.savings;
      case 'chequera': return Icons.account_balance;
      case 'inversion': return Icons.trending_up;
      default: return Icons.wallet;
    }
  }
}
