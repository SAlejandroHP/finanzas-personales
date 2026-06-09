import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/master_plan_models.dart';
import '../providers/master_plan_provider.dart';

class MasterPlanCard extends ConsumerStatefulWidget {
  const MasterPlanCard({Key? key}) : super(key: key);

  @override
  ConsumerState<MasterPlanCard> createState() => _MasterPlanCardState();
}

class _MasterPlanCardState extends ConsumerState<MasterPlanCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surface;

    final phases = ref.watch(masterPlanProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'CALENDARIO MAESTRO FINZAI',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodySmall,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary.withOpacity(0.8),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              if (phases.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _isExpanded ? 'Ocultar' : 'Expandir',
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodySmall,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: phases.isEmpty
              ? _buildEmptyState(isDark)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código de Operaciones Generado',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ejecución estratégica dinámica calculada a 45 días.',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._buildPhasesList(phases, isDark),
                    if (!_isExpanded && phases.length > 1)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '+ Expandir para ver todas las estrategias y meses',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.query_stats, size: 48, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'El Motor de Inteligencia está inactivo.',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tarjetas de crédito con fechas de corte, deudas o ingresos/gastos recurrentes para que el motor empiece a trazar tu hoja de ruta estratégica.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPhasesList(List<PlanPhase> phases, bool isDark) {
    List<Widget> widgets = [];
    
    for (int i = 0; i < phases.length; i++) {
      if (i > 0 && !_isExpanded) break; // Solo mostrar la primera fase si no está expandido

      final phase = phases[i];
      widgets.add(_buildPhase(
        title: phase.title,
        subtitle: phase.subtitle,
        isDark: isDark,
        items: phase.milestones.asMap().entries.map((entry) {
          final isLast = entry.key == phase.milestones.length - 1;
          final milestone = entry.value;
          
          final DateFormat formatter = DateFormat('E d MMM', 'es_MX');
          final dateStr = formatter.format(milestone.date);
          
          return _buildTimelineItem(
            date: '${dateStr[0].toUpperCase()}${dateStr.substring(1)}',
            title: milestone.title,
            isDark: isDark,
            actions: milestone.actions.map((action) => _buildActionPill(action, isDark)).toList(),
            note: milestone.note,
            bullets: milestone.bulletPoints,
            isLastInSection: isLast,
          );
        }).toList(),
      ));
      
      if (i < phases.length - 1 && _isExpanded) {
        widgets.add(const SizedBox(height: 24));
      }
    }
    
    return widgets;
  }

  Widget _buildPhase({
    required String title,
    required String subtitle,
    required bool isDark,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _buildTimelineItem({
    required String date,
    required String title,
    required bool isDark,
    required List<Widget> actions,
    String? note,
    List<String> bullets = const [],
    bool isLastInSection = false,
  }) {
    return Stack(
      children: [
        // Timeline graphics line
        if (!isLastInSection)
          Positioned(
            left: 5, // center of the 12px dot
            top: 16, // dot height + margin
            bottom: 0,
            child: Container(
              width: 2,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
        // Content
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline dot
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Main content column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          date,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actions,
                    ),
                    if (bullets.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildActionRow('Blindaje Inmediato:', bullets, isDark),
                    ],
                    if (note != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          border: Border(
                            left: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 3),
                          ),
                        ),
                        child: Text(
                          note,
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getColorForActionType(ActionType type) {
    switch (type) {
      case ActionType.income:
        return Colors.green;
      case ActionType.expense:
        return Colors.orange;
      case ActionType.rule:
        return Colors.redAccent;
      case ActionType.payment:
        return AppColors.primary;
      case ActionType.leverage:
        return AppColors.secondary;
      case ActionType.info:
        return Colors.grey;
    }
  }

  Widget _buildActionPill(PlanAction action, bool isDark) {
    final color = _getColorForActionType(action.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${action.label}: ',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            TextSpan(
              text: action.description,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, List<String> items, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items.map((item) {
              return Text(
                '• $item',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
