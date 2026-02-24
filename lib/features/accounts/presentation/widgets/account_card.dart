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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? onEdit,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mostrar logo o Icono en Squircle R:10
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10), // Squircle
                        ),
                        child: Icon(
                          theme.icon,
                          color: theme.color,
                          size: 20,
                        ),
                      ),
                      // Menú de acciones pequeño (SM)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
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
                  const Spacer(),
                  // Nombre y Tipo
                  Text(
                    account.nombre,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    theme.label.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Saldo principal
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      currencyFormatter.format(account.saldoActual),
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
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
