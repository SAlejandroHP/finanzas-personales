import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/ui_provider.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../transactions/presentation/screens/recurring_transactions_screen.dart';

/// Pantalla de configuración de la aplicación.
/// Organizada de forma funcional con secciones de gestión, apariencia y cuenta.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final user = supabaseClient.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: isDark ? const Color(0xFF121212) : AppColors.backgroundColor,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppColors.md),
          children: [
            // SECCIÓN: PERFIL / CUENTA
            if (user != null) ...[
              _buildSectionHeader(context, 'Cuenta'),
              _buildProfileCard(context, user.email ?? 'Usuario', isDark),
              const SizedBox(height: AppColors.md),
            ],

            // SECCIÓN: GESTIÓN (CORE)
            _buildSectionHeader(context, 'Gestión Financiera'),
            _buildNavigationCard(
              context,
              isDark,
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.primary,
              title: 'Mis Cuentas',
              subtitle: 'Bancos, efectivo y billeteras virtuales',
              onTap: () => context.push('/accounts'),
            ),
            const SizedBox(height: AppColors.sm),
            _buildNavigationCard(
              context,
              isDark,
              icon: Icons.grid_view_outlined,
              iconColor: AppColors.secondary,
              title: 'Mis Categorías',
              subtitle: 'Organiza tus ingresos y gastos',
              onTap: () => context.push('/categories'),
            ),
            const SizedBox(height: AppColors.sm),
            _buildNavigationCard(
              context,
              isDark,
              icon: Icons.repeat_rounded,
              iconColor: Colors.orange,
              title: 'Transacciones Recurrentes',
              subtitle: 'Configura sueldos y pagos automáticos',
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => RecurringTransactionsScreen())
              ),
            ),
            const SizedBox(height: AppColors.sm),
            _buildNavigationCard(
              context,
              isDark,
              icon: Icons.credit_score_outlined,
              iconColor: Colors.redAccent,
              title: 'Mis Deudas',
              subtitle: 'Préstamos, deudas con familiares y servicios',
              onTap: () => context.push('/settings/debts'),
            ),
            const SizedBox(height: AppColors.lg),

            // SECCIÓN: PREFERENCIAS
            _buildSectionHeader(context, 'Personalización'),
            _buildSettingCard(
              context,
              isDark,
              icon: Icons.palette_outlined,
              iconColor: Colors.purple,
              title: 'Apariencia',
              subtitle: 'Cambia el tema visual de la aplicación',
              child: SegmentedButton<AppThemeMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  side: BorderSide.none,
                ),
                segments: [
                  ButtonSegment(
                    value: AppThemeMode.light,
                    label: Text('Claro', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, fontWeight: FontWeight.w500)),
                    icon: const Icon(Icons.light_mode_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    label: Text('Oscuro', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, fontWeight: FontWeight.w500)),
                    icon: const Icon(Icons.dark_mode_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.system,
                    label: Text('Auto', style: GoogleFonts.montserrat(fontSize: AppColors.bodySmall, fontWeight: FontWeight.w500)),
                    icon: const Icon(Icons.smartphone_outlined, size: 16),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (newSelection) {
                  ref.read(themeModeProvider.notifier).state = newSelection.first;
                },
              ),
            ),
            const SizedBox(height: AppColors.lg),

            const SizedBox(height: AppColors.xl * 2),
            
            // Versión de la app
            Center(
              child: Text(
                'v1.0.0',
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.bodySmall,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye el encabezado de una sección
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppColors.lg, AppColors.md, AppColors.lg, AppColors.sm),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: AppColors.bodySmall,
          fontWeight: FontWeight.w700,
          color: AppColors.primary.withOpacity(0.8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Tarjeta de perfil del usuario
  Widget _buildProfileCard(BuildContext context, String email, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppColors.lg),
      padding: const EdgeInsets.all(AppColors.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: const Icon(Icons.person_outline, color: AppColors.primary),
          ),
          const SizedBox(width: AppColors.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola 👋',
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodyMedium,
                    color: isDark ? Colors.white70 : AppColors.textPrimary.withOpacity(0.6),
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodyLarge,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una tarjeta de configuración con control (como el toggle de tema)
  Widget _buildSettingCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppColors.lg),
      padding: const EdgeInsets.all(AppColors.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppColors.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodyLarge,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: AppColors.bodySmall,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppColors.lg),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }

  /// Construye una tarjeta de navegación
  Widget _buildNavigationCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppColors.lg),
        padding: const EdgeInsets.all(AppColors.lg),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppColors.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodySmall,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
               Icons.chevron_right_outlined,
              color: isDark ? Colors.white30 : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
