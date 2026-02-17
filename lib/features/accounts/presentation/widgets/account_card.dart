import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/account_model.dart';

/// Widget card estilo grid para mostrar una cuenta financiera de forma creativa y consistente.
class AccountCard extends StatelessWidget {
  final AccountModel account;
  final String currencySymbol;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const AccountCard({
    Key? key,
    required this.account,
    this.currencySymbol = '\$',
    this.onEdit,
    this.onDelete,
    this.onTap,
  }) : super(key: key);

  /// Retorna el tema visual basado en el tipo de cuenta
  _AccountTypeTheme _getThemeForType(String tipo) {
    switch (tipo) {
      case 'efectivo':
        return const _AccountTypeTheme(
          icon: Icons.payments_outlined,
          color: Colors.green,
          label: 'Efectivo',
        );
      case 'chequera':
        return const _AccountTypeTheme(
          icon: Icons.account_balance_outlined,
          color: Colors.blue,
          label: 'Chequera',
        );
      case 'ahorro':
        return const _AccountTypeTheme(
          icon: Icons.savings_outlined,
          color: Colors.purple,
          label: 'Ahorros',
        );
      case 'tarjeta_credito':
        return const _AccountTypeTheme(
          icon: Icons.credit_card_outlined,
          color: Colors.red,
          label: 'Crédito',
        );
      case 'inversion':
        return const _AccountTypeTheme(
          icon: Icons.trending_up_outlined,
          color: Colors.orange,
          label: 'Inversión',
        );
      default:
        return const _AccountTypeTheme(
          icon: Icons.help_outline,
          color: Colors.blueGrey,
          label: 'Otro',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = _getThemeForType(account.tipo);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    final currencyFormatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: theme.color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? onEdit,
            child: Stack(
              children: [
                // Decoración sutil de fondo
                Positioned(
                  right: -10,
                  top: -10,
                  child: Icon(
                    theme.icon,
                    size: 80,
                    color: theme.color.withOpacity(0.03),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Parte superior: Icono y Menú
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Mostrar logo del banco si existe
                          if (account.bancoLogo != null && account.bancoLogo!.isNotEmpty)
                            Container(
                              width: 36,
                              height: 36,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.color.withOpacity(0.2),
                                ),
                              ),
                              child: Image.network(
                                account.bancoLogo!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  theme.icon,
                                  color: theme.color,
                                  size: 18,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                theme.icon,
                                color: theme.color,
                                size: 18,
                              ),
                            ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 18,
                              color: isDark ? Colors.white38 : Colors.grey[400],
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'edit') onEdit?.call();
                              if (value == 'delete') onDelete?.call();
                            },
                            itemBuilder: (context) => [
                              _buildPopupMenuItem('edit', Icons.edit_outlined, 'Editar'),
                              _buildPopupMenuItem('delete', Icons.delete_outline, 'Eliminar', isDestructive: true),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Centro: Nombre
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.nombre,
                            style: GoogleFonts.montserrat(
                              fontSize: AppColors.bodySmall,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            theme.label,
                            style: GoogleFonts.montserrat(
                              fontSize: AppColors.bodySmall,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),

                      // Base: Saldo
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          currencyFormatter.format(account.saldoActual),
                          style: GoogleFonts.montserrat(
                            fontSize: AppColors.bodyLarge,
                            fontWeight: FontWeight.w800,
                            color: _getBalanceColor(),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Línea de acento inferior
                Positioned(
                  bottom: 0,
                  left: 20,
                  right: 20,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.color.withOpacity(0.3),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String value, IconData icon, String label, {bool isDestructive = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDestructive ? Colors.red : null),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: AppColors.bodySmall,
              color: isDestructive ? Colors.red : null,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBalanceColor() {
    if (account.saldoActual > 0) return Colors.green;
    if (account.saldoActual < 0) return AppColors.secondary;
    return Colors.grey;
  }
}

class _AccountTypeTheme {
  final IconData icon;
  final Color color;
  final String label;

  const _AccountTypeTheme({
    required this.icon,
    required this.color,
    required this.label,
  });
}
