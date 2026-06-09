import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/bank_logo.dart';
import '../../models/account_model.dart';
import 'account_list_tile.dart';

class BankGroupCard extends StatefulWidget {
  final String bankName;
  final String? bankLogo;
  final String primaryColor;
  final List<AccountModel> accounts;
  final String currencySymbol;
  final Function(AccountModel) onEdit;
  final Function(AccountModel) onDelete;
  final Function(AccountModel) onTap;

  const BankGroupCard({
    Key? key,
    required this.bankName,
    this.bankLogo,
    required this.primaryColor,
    required this.accounts,
    this.currencySymbol = '\$',
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  }) : super(key: key);

  @override
  State<BankGroupCard> createState() => _BankGroupCardState();
}

class _BankGroupCardState extends State<BankGroupCard> {
  bool _isExpanded = false;

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bankColor = _parseColor(widget.primaryColor);

    // Calcular saldos
    double totalLiquidez = 0;
    double totalCreditoDisponible = 0;
    bool hasLiquidez = false;

    for (var acc in widget.accounts) {
      if (acc.tipo != 'tarjeta_credito') {
        totalLiquidez += acc.saldoActual;
        hasLiquidez = true;
      } else {
        totalCreditoDisponible += acc.saldoActual;
      }
    }
    
    // Si tiene liquidez (Ahorro/Débito/Efectivo), mostramos eso (Regla 1 finzAi: Efectivo manda).
    // Si SOLO tiene tarjetas de crédito, mostramos el crédito disponible.
    final displayValue = hasLiquidez ? totalLiquidez : totalCreditoDisponible;
    final isOnlyCredit = !hasLiquidez && widget.accounts.isNotEmpty;

    final currencyFormatter = NumberFormat.currency(
      symbol: widget.currencySymbol,
      decimalDigits: 2,
    );

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
              child: Row(
                children: [
                  // Logo del Banco
                  BankLogo(
                    bankName: widget.bankName,
                    primaryColor: widget.primaryColor.replaceAll('#', ''),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  // Info del Banco
                  Expanded(
                    child: Text(
                      widget.bankName,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Saldo Consolidado
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currencyFormatter.format(displayValue),
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: displayValue < 0 
                              ? Colors.redAccent 
                              : (isOnlyCredit ? Colors.grey : (isDark ? Colors.white : AppColors.textPrimary)),
                        ),
                      ),
                      if (isOnlyCredit)
                        Text(
                          'Disponible',
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Contenido expandible
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Container(
            constraints: _isExpanded
                ? const BoxConstraints(maxHeight: 2000)
                : const BoxConstraints(maxHeight: 0),
            margin: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                ...widget.accounts.map((acc) => AccountListTile(
                      account: acc,
                      currencySymbol: widget.currencySymbol,
                      onEdit: () => widget.onEdit(acc),
                      onDelete: () => widget.onDelete(acc),
                      onTap: () => widget.onTap(acc),
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
      ],
    );
  }
}
