import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/goal_model.dart';

class GoalCard extends StatelessWidget {
  final GoalModel goal;
  final VoidCallback? onTap;

  const GoalCard({
    Key? key,
    required this.goal,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : Colors.white;
    final currencyFormatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);
    
    // Color de la meta
    final goalColor = Color(int.parse(goal.colorHex.replaceFirst('#', '0xFF')));
    final progress = goal.progress;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppColors.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: goalColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIconData(goal.icon),
                        color: goalColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          if (goal.deadline != null)
                            Text(
                              'Meta: ${DateFormat('MMM yyyy').format(goal.deadline!)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: AppColors.description,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormatter.format(goal.targetAmount),
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Objetivo',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: AppColors.description,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% completado',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: goalColor,
                      ),
                    ),
                    Text(
                      'Ahorrado: ${currencyFormatter.format(goal.currentAmount)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                if (goal.suggestedMonthlySavings != null && !goal.isCompleted) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        'Ahorro sugerido: ${currencyFormatter.format(goal.suggestedMonthlySavings!)}/mes',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.description,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'savings': return Icons.savings_outlined;
      case 'flight': return Icons.flight_takeoff;
      case 'home': return Icons.home_outlined;
      case 'car': return Icons.directions_car_outlined;
      case 'laptop': return Icons.laptop_mac_outlined;
      case 'beach': return Icons.beach_access_outlined;
      case 'gift': return Icons.card_giftcard_outlined;
      default: return Icons.star_border;
    }
  }
}
