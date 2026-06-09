import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class MasterPlanCard extends StatefulWidget {
  const MasterPlanCard({Key? key}) : super(key: key);

  @override
  State<MasterPlanCard> createState() => _MasterPlanCardState();
}

class _MasterPlanCardState extends State<MasterPlanCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surface;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Código de Operaciones',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ejecución estratégica para no descapitalizarte.',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              _buildPhase(
                title: '🔴 Fase 1: Contención y Viaje',
                subtitle: '15 al 30 de Junio',
                isDark: isDark,
                items: [
                  _buildTimelineItem(
                    date: 'Lun 15 Jun',
                    title: 'Quincena y Despliegue de Efectivo',
                    isDark: isDark,
                    actions: [
                      _buildActionPill('Ingreso', '+\$17,500.00', Colors.green, isDark),
                      _buildActionPill('Reserva', 'Retira \$329.46', Colors.orange, isDark),
                      _buildActionRow('Blindaje Inmediato:', [
                        'Renta: \$4,000.00',
                        'Comida: \$3,500.00',
                        'Mayordomía: \$2,500.00',
                        'Escuela: \$1,800.00',
                        'Viaje SD: \$1,500.00',
                        'Kueski: \$1,472.15',
                        'Deuda + IKEA: \$1,566.00',
                        'Fruta: \$600.00',
                        'Nu Préstamo: \$541.31',
                        'Gas: \$350.00',
                      ], isDark),
                    ],
                    note: 'Tu cuenta de débito queda en ceros, pero familia, techo y escuela 100% cubiertos.',
                  ),
                  _buildTimelineItem(
                    date: 'Mar 16 Jun',
                    title: 'Contención de Stori',
                    isDark: isDark,
                    actions: [
                      _buildActionPill('Acción', 'Transfiere sobrante Nu (\$1,579.62) a Stori', AppColors.primary, isDark),
                    ],
                    note: 'Superas pago mínimo y cruzas el corte limpiecito.',
                  ),
                  if (_isExpanded) ...[
                    _buildTimelineItem(
                      date: 'Mié 17 Jun',
                      title: 'Límite Stori',
                      isDark: isDark,
                      actions: [
                         _buildActionPill('Status', 'Ya cubierto el día 16', Colors.grey, isDark),
                      ],
                    ),
                    _buildTimelineItem(
                      date: 'Vie 26 Jun',
                      title: 'El Viaje a San Diego',
                      isDark: isDark,
                      actions: [
                        _buildActionPill('Ejecución', 'Pago físico de inscripciones', AppColors.secondary, isDark),
                      ],
                    ),
                  ],
                  _buildTimelineItem(
                    date: 'Mar 30 Jun',
                    title: 'Quincena y Reinicio',
                    isDark: isDark,
                    actions: [
                      _buildActionPill('Ingreso', '+\$17,500.00', Colors.green, isDark),
                      _buildActionPill('Crítica', 'Separar \$2,508.81 para tarjeta Klar (AT&T pateado)', Colors.redAccent, isDark),
                    ],
                    isLastInSection: true,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 24),
                _buildPhase(
                  title: '🔵 Fase 2: Choque Escolar y Apalancamiento',
                  subtitle: '1 al 31 de Julio',
                  isDark: isDark,
                  items: [
                    _buildTimelineItem(
                      date: 'Mié 1 Jul',
                      title: 'Corte de Klar',
                      isDark: isDark,
                      actions: [
                        _buildActionPill('Regla', 'NO usar la tarjeta hoy', Colors.redAccent, isDark),
                      ],
                    ),
                    _buildTimelineItem(
                      date: 'Jue 2 Jul',
                      title: 'Apalancamiento Regalo Mía',
                      isDark: isDark,
                      actions: [
                        _buildActionPill('Acción', 'Compra regalo Mía con Klar', AppColors.primary, isDark),
                      ],
                      note: 'El pago se patea automáticamente 40 días, hasta el 11 de agosto.',
                    ),
                    _buildTimelineItem(
                      date: '5 al 10 Jul',
                      title: 'Apalancamiento Plata',
                      isDark: isDark,
                      actions: [
                         _buildActionPill('Acción', 'Pagar Totalplay (\$790) con Plata', AppColors.secondary, isDark),
                      ],
                      note: 'Ganas 60 días de margen.',
                    ),
                    _buildTimelineItem(
                      date: 'Sáb 11 Jul',
                      title: 'Límite de Klar',
                      isDark: isDark,
                      actions: [
                         _buildActionPill('Pago', 'Paga los \$2,508.81 del AT&T con reserva del 30 Jun', AppColors.primary, isDark),
                      ],
                    ),
                    _buildTimelineItem(
                      date: 'Mié 15 Jul',
                      title: 'Quincena y Choque',
                      isDark: isDark,
                      actions: [
                        _buildActionPill('Ingreso', '+\$17,500.00', Colors.green, isDark),
                        _buildActionRow('Blindaje:', [
                          'Uniformes: \$3,540.00',
                          'Mayordomía: \$2,500.00',
                          'Renta: \$4,000.00',
                          'Comida: \$3,500.00',
                          'Deuda Ismael: \$1,000.00',
                          'Fruta: \$600.00',
                          'Gas: \$350.00',
                        ], isDark),
                        _buildActionPill('Remanente', '\$2,010.00 Libres', Colors.green, isDark),
                      ],
                    ),
                    _buildTimelineItem(
                      date: 'Jue 16 Jul',
                      title: 'Golpe a Stori',
                      isDark: isDark,
                      actions: [
                        _buildActionPill('Inyección', '\$2,010.00 íntegros a Stori', AppColors.primary, isDark),
                      ],
                    ),
                    _buildTimelineItem(
                      date: 'Mié 22 Jul',
                      title: 'Cumpleaños Mía y Corte Nu',
                      isDark: isDark,
                      actions: [
                         _buildActionPill('Regla', 'NO usar Nu hoy', Colors.redAccent, isDark),
                      ],
                    ),
                    _buildTimelineItem(
                      date: 'Jue 23 Jul',
                      title: 'Apalancamiento Regalo Eiden',
                      isDark: isDark,
                      actions: [
                        _buildActionPill('Acción', 'Compra regalo Eiden con Nu', AppColors.secondary, isDark),
                      ],
                      note: 'Al hacerlo 1 día después del corte, ganas 40 días. Se patea al 2 de Sep.',
                    ),
                    _buildTimelineItem(
                      date: 'Vie 31 Jul',
                      title: 'Quincena y Revisión Algorítmica',
                      isDark: isDark,
                      actions: [
                        _buildActionPill('Ingreso', '+\$17,500.00', Colors.green, isDark),
                        _buildActionPill('Revisión', 'Verificar app Nu para préstamo personal', AppColors.primary, isDark),
                      ],
                      note: 'Preparar liquidez para la mudanza del 8 de agosto.',
                      isLastInSection: true,
                    ),
                  ],
                ),
              ],
              if (!_isExpanded)
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
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
    bool isLastInSection = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline graphics
          Column(
            children: [
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
              if (!isLastInSection)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
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
    );
  }

  Widget _buildActionPill(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
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
