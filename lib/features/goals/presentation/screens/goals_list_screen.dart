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
      appBar: AppBar(
        title: Text(
          'Mis Metas',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
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
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen de ahorro total
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppColors.pagePadding),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(AppColors.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Ahorrado en Metas',
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormatter.format(totalSaved),
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
