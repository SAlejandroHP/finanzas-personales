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
    double totalEfectivo = 0;
    double totalDeuda = 0;
    for (var acc in widget.accounts) {
      if (acc.tipo == 'tarjeta_credito') {
        totalDeuda += (acc.saldoInicial - acc.saldoActual); // deudaActual = limite - disponible
      } else {
        totalEfectivo += acc.saldoActual;
      }
    }
    
    // El saldo neto total del banco (Efectivo/Ahorro - Deudas de TDC)
    final totalNeto = totalEfectivo - totalDeuda;

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
                  Text(
                    currencyFormatter.format(totalNeto),
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: totalNeto < 0 
                          ? Colors.redAccent 
                          : (isDark ? Colors.white : AppColors.textPrimary),
                    ),
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
