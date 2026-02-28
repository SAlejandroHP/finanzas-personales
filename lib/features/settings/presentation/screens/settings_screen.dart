import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/ui_provider.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/presentation/screens/recurring_transactions_screen.dart';

/// Pantalla de configuración de la aplicación.
/// Organizada de forma funcional con secciones de gestión, apariencia y cuenta.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    final user = supabaseClient.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] ?? '';
    _nameController = TextEditingController(text: displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateName() async {
    if (_nameController.text.trim().isEmpty) return;

    try {
      await ref.read(authNotifierProvider.notifier).updateDisplayName(_nameController.text.trim());
      setState(() {
        _isEditingName = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nombre actualizado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        centerTitle: false,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
        children: [
          // SECCIÓN: PERFIL / CUENTA
          if (user != null) ...[
            _buildSectionHeader(context, 'Cuenta'),
            _buildProfileCard(context, user, isDark),
            const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          _buildNavigationCard(
            context,
            isDark,
            icon: Icons.grid_view_outlined,
            iconColor: AppColors.secondary,
            title: 'Mis Categorías',
            subtitle: 'Organiza tus ingresos y gastos',
            onTap: () => context.push('/categories'),
          ),
          const SizedBox(height: 8),
          _buildNavigationCard(
            context,
            isDark,
            icon: Icons.repeat_rounded,
            iconColor: Colors.orange,
            title: 'Transacciones Recurrentes',
            subtitle: 'Configura sueldos y pagos automáticos',
            onTap: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => RecurringTransactionsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _buildNavigationCard(
            context,
            isDark,
            icon: Icons.credit_score_outlined,
            iconColor: Colors.redAccent,
            title: 'Mis Deudas',
            subtitle: 'Préstamos, deudas con familiares y servicios',
            onTap: () => context.push('/settings/debts'),
          ),
          const SizedBox(height: 8),
          _buildNavigationCard(
            context,
            isDark,
            icon: Icons.track_changes_rounded,
            iconColor: Colors.teal,
            title: 'Mis Metas de Ahorro',
            subtitle: 'Viajes, fondos de emergencia y compras',
            onTap: () => context.push('/goals'),
          ),
          const SizedBox(height: 16),

          // SECCIÓN: PREFERENCIAS
          _buildSectionHeader(context, 'Personalización'),
          _buildSettingCard(
            context,
            isDark,
            icon: Icons.palette_rounded,
            iconColor: Colors.deepPurpleAccent,
            title: 'Apariencia del Sistema',
            subtitle: 'Cambia el tema visual de la aplicación',
            child: SegmentedButton<AppThemeMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                visualDensity: VisualDensity.compact, // Compacto para evitar cortes
              ),
              segments: [
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Claro', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  icon: const Icon(Icons.light_mode_rounded, size: 16),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Oscuro', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  icon: const Icon(Icons.dark_mode_rounded, size: 16),
                ),
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Auto', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  icon: const Icon(Icons.smartphone_outlined, size: 16),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (newSelection) {
                ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
              },
            ),
          ),
          const SizedBox(height: 48),

          // BOTÓN CERRAR SESIÓN (Premium)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextButton(
              onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.redAccent.withOpacity(0.08),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Cerrar sesión de forma segura',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(isDark),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Construye el encabezado de una sección
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppColors.lg + 4, 32, AppColors.lg, 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primary.withOpacity(0.6),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  /// Footer con información de la app
  Widget _buildFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded, 
              size: 20, 
              color: isDark ? Colors.white30 : Colors.black26
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Finanzas Personales Premium',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Versión 2.0.0 • 2024',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de perfil del usuario con edición integrada (Rediseño Premium)
  Widget _buildProfileCard(BuildContext context, User user, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppColors.lg),
      padding: const EdgeInsets.all(AppColors.lg),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10), // Squircle homologado
            ),
            child: const Icon(
              Icons.person_outline,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppColors.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.montserrat(
                    fontSize: AppColors.bodyLarge,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tu nombre',
                    hintStyle: GoogleFonts.montserrat(
                      fontSize: AppColors.bodyLarge,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    suffixIcon: !_isEditingName 
                      ? Icon(Icons.edit_rounded, size: 14, color: Colors.grey.withOpacity(0.4)) 
                      : null,
                    suffixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    if (!_isEditingName) setState(() => _isEditingName = true);
                  },
                ),
                Text(
                  user.email ?? '',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isEditingName) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _updateName,
              icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
              tooltip: 'Guardar cambios',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  /// Construye una tarjeta de configuración con control (Rediseño Premium)
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10), // Squircle homologado
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  /// Construye una tarjeta de navegación (Rediseño Premium)
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10), // Squircle homologado
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
               Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : Colors.grey[300],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
