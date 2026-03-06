import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/ui_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/goal_model.dart';
import '../providers/goals_provider.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_form_bottom_sheet.dart';
import '../widgets/goal_contribution_sheet.dart';

class GoalsListScreen extends ConsumerWidget {
  const GoalsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalsAsync = ref.watch(goalsListProvider);
    final totalSaved = ref.watch(totalGoalsSavedProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundColor,
      body: Column(
        children: [
          // Premium Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Mis Metas',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
                    ),
                    onPressed: () => _showGoalForm(context, ref),
                  ),
                ],
              ),
            ),
          ),
          // Resumen de ahorro total
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppColors.pagePadding),
            decoration: BoxDecoration(
              color: AppColors.goals.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL AHORRADO EN METAS',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormatter.format(totalSaved),
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Barra inferior con indicadores (Estilo Dashboard/Cuentas)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: goalsAsync.when(
                            data: (goals) => _buildCompactIndicator(
                              'Metas',
                              '${goals.length}',
                              Colors.white,
                              Icons.flag_rounded,
                            ),
                            loading: () => const SizedBox(),
                            error: (_, __) => const SizedBox(),
                          ),
                        ),
                        Container(height: 20, width: 1, color: Colors.white.withOpacity(0.15)),
                        Expanded(
                          child: goalsAsync.when(
                            data: (goals) {
                              final avgProgress = goals.isEmpty 
                                  ? 0.0 
                                  : goals.fold<double>(0, (sum, g) => sum + g.progress) / goals.length;
                              return _buildCompactIndicator(
                                'Progreso',
                                '${(avgProgress * 100).toInt()}%',
                                Colors.white.withOpacity(0.8),
                                Icons.trending_up_rounded,
                              );
                            },
                            loading: () => const SizedBox(),
                            error: (_, __) => const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: goalsAsync.when(
              data: (goals) {
                if (goals.isEmpty) {
                  return _buildEmptyState(context, ref);
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppColors.pagePadding),
                  physics: const BouncingScrollPhysics(),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    return GoalCard(
                      goal: goal,
                      onTap: () => _showGoalOptions(context, ref, goal),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          const SizedBox(height: 80), // Espacio para el nav bar flotante
        ],
      ),
    );
  }

  Widget _buildCompactIndicator(String label, String amount, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 10, color: color.withOpacity(0.8)),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: color.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.track_changes_outlined, size: 80, color: AppColors.description.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes metas de ahorro',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.description,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Define un objetivo y empieza a ahorrar hoy.',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: AppColors.description.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showGoalForm(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Crear mi primera meta'),
          ),
        ],
      ),
    );
  }

  void _showGoalForm(BuildContext context, WidgetRef ref, {GoalModel? goal}) {
    ref.read(isCanvasOpenProvider.notifier).state = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalFormBottomSheet(goal: goal),
    ).then((_) {
      ref.read(isCanvasOpenProvider.notifier).state = false;
    });
  }

  void _showGoalOptions(BuildContext context, WidgetRef ref, GoalModel goal) {
    ref.read(isCanvasOpenProvider.notifier).state = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(
              goal.title,
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              title: const Text('Hacer un aporte'),
              onTap: () {
                Navigator.pop(context);
                _showContributionSheet(context, ref, goal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: const Text('Editar meta'),
              onTap: () {
                Navigator.pop(context);
                _showGoalForm(context, ref, goal: goal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Eliminar meta'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref, goal);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).then((_) {
      ref.read(isCanvasOpenProvider.notifier).state = false;
    });
  }

  void _showContributionSheet(BuildContext context, WidgetRef ref, GoalModel goal) {
    ref.read(isCanvasOpenProvider.notifier).state = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalContributionSheet(goal: goal),
    ).then((_) {
      ref.read(isCanvasOpenProvider.notifier).state = false;
    });
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GoalModel goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar meta?'),
        content: const Text('Esta acción no se puede deshacer y no devolverá el dinero a tus cuentas automáticamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              ref.read(goalsNotifierProvider.notifier).deleteGoal(goal.id);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
