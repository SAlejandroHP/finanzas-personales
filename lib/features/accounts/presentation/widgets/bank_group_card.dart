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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: baseColor,
        gradient: LinearGradient(
          colors: [
            bankColor.withOpacity(isDark ? 0.15 : 0.05),
            baseColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.4],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: bankColor.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : bankColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      // Logo del Banco
                      BankLogo(
                        bankName: widget.bankName,
                        primaryColor: widget.primaryColor.replaceAll('#', ''),
                        size: 48,
                      ),
                      const SizedBox(width: 16),
                      // Info del Banco
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.bankName,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.accounts.length} producto${widget.accounts.length != 1 ? 's' : ''}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Saldo Consolidado
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormatter.format(totalNeto),
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: totalNeto < 0 
                                  ? Colors.redAccent 
                                  : (isDark ? Colors.white : AppColors.textPrimary),
                              letterSpacing: -0.5,
                            ),
                          ),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: isDark ? Colors.white38 : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Contenido expandible
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              child: Container(
                constraints: _isExpanded
                    ? const BoxConstraints(maxHeight: 1000)
                    : const BoxConstraints(maxHeight: 0),
                child: Column(
                  children: [
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[100]),
                    ...widget.accounts.map((acc) => AccountListTile(
                          account: acc,
                          currencySymbol: widget.currencySymbol,
                          onEdit: () => widget.onEdit(acc),
                          onDelete: () => widget.onDelete(acc),
                          onTap: () => widget.onTap(acc),
                        )),
                    const SizedBox(height: 8), // Padding inferior
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
