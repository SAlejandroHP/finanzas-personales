import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/account_model.dart';

class AccountListTile extends StatelessWidget {
  final AccountModel account;
  final String currencySymbol;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const AccountListTile({
    Key? key,
    required this.account,
    this.currencySymbol = '\$',
    this.onEdit,
    this.onDelete,
    this.onTap,
  }) : super(key: key);

  _AccountTypeTheme _getThemeForType(String tipo) {
    switch (tipo) {
      case 'efectivo':
        return const _AccountTypeTheme(icon: Icons.payments_outlined, color: Colors.green, label: 'Efectivo');
      case 'chequera':
        return const _AccountTypeTheme(icon: Icons.account_balance_outlined, color: Colors.blue, label: 'Débito');
      case 'ahorro':
        return const _AccountTypeTheme(icon: Icons.savings_outlined, color: Colors.purple, label: 'Ahorros');
      case 'tarjeta_credito':
        return const _AccountTypeTheme(icon: Icons.credit_card_outlined, color: Colors.red, label: 'Crédito');
      case 'inversion':
        return const _AccountTypeTheme(icon: Icons.trending_up_outlined, color: Colors.orange, label: 'Inversión');
      default:
        return const _AccountTypeTheme(icon: Icons.help_outline, color: Colors.blueGrey, label: 'Otro');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = _getThemeForType(account.tipo);
    final isTC = account.tipo == 'tarjeta_credito';
    
    final currencyFormatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  theme.icon,
                  color: theme.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.nombre,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      theme.label,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormatter.format(account.saldoActual),
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (isTC && account.saldoInicial > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Límite: ${currencyFormatter.format(account.saldoInicial)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ]
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
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
