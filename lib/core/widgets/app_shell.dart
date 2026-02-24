import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/ui_provider.dart';
import '../../features/transactions/presentation/widgets/transaction_form_sheet.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Provider para mantener el índice de la ruta activa en la navegación
final navigationIndexProvider = StateProvider<int>((ref) => 0);

/// Modelo para los ítems del BottomNavigationBar
class NavItem {
  final String label;
  final IconData icon;
  final String path;
  final int index;

  NavItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.index,
  });
}

/// Widget shell que contiene el BottomNavigationBar tipo "island"
/// Se usa con GoRouter para envolver todas las rutas principales
class AppShell extends ConsumerWidget {
  /// Pantalla actual a mostrar
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location.startsWith('/transactions')) {
      currentIndex = 1;
    } else if (location.startsWith('/settings') || 
               location.startsWith('/accounts') || 
               location.startsWith('/categories')) {
      currentIndex = 2;
    }
    final isCanvasOpen = ref.watch(isCanvasOpenProvider);

    // Ítems de navegación reorganizados por relevancia
    final navItems = [
      NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        path: '/',
        index: 0,
      ),
      NavItem(
        label: 'Transacciones',
        icon: Icons.receipt_long_outlined,
        path: '/transactions',
        index: 1,
      ),
      NavItem(
        label: 'Configuración',
        icon: Icons.settings_outlined,
        path: '/settings',
        index: 2,
      ),
      NavItem(
        label: 'Salir',
        icon: Icons.logout_outlined,
        path: '', // No navega, dispara acción
        index: 3,
      ),
    ];

    final isNavbarVisible = ref.watch(isNavbarVisibleProvider);

    return Scaffold(
      extendBody: true,
      body: child,
      // Quitamos el FAB del slot tradicional para integrarlo o posicionarlo mejor
      floatingActionButton: !isCanvasOpen 
          ? AnimatedSlide(
              offset: isNavbarVisible ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _buildCenterFAB(context, ref),
            ) 
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: !isCanvasOpen
          ? AnimatedSlide(
              offset: isNavbarVisible ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 5),
                child: SafeArea(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? const Color(0xFF2C2C2C).withOpacity(0.95) 
                            : const Color(0xFFF0F0F0).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.black.withOpacity(0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavButton(context, ref, navItems[0], currentIndex == 0),
                          _buildNavButton(context, ref, navItems[1], currentIndex == 1),
                          const SizedBox(width: 48),
                          _buildNavButton(context, ref, navItems[2], currentIndex == 2),
                          _buildNavButton(context, ref, navItems[3], false),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  /// Construye un botón de navegación con animación
  Widget _buildNavButton(
    BuildContext context,
    WidgetRef ref,
    NavItem item,
    bool isActive,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (item.label == 'Salir') {
            _showLogoutConfirmation(context, ref);
          } else {
            context.go(item.path);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive 
                    ? AppColors.primary.withOpacity(0.15) 
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                size: 24,
                color: isActive
                    ? AppColors.primary
                    : (isDark ? Colors.white54 : Colors.grey[600]),
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Muestra un diálogo de confirmación para logout
  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Cerrar sesión?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Tendrás que iniciar sesión nuevamente para acceder a tu cuenta.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.montserrat(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/auth');
              }
            },
            child: Text(
              'Cerrar sesión',
              style: GoogleFonts.montserrat(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el FAB central flotante
  Widget _buildCenterFAB(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(top: 54), // Bajamos el FAB aún más para que siga alineado con el nav bajado
      child: FloatingActionButton(
        onPressed: () => _showAddTransactionSheet(context, ref),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.add,
          size: 30,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Muestra un bottom sheet para agregar transacción
  void _showAddTransactionSheet(BuildContext context, WidgetRef ref) {
    ref.read(isCanvasOpenProvider.notifier).state = true;
    showTransactionFormSheet(context).then((_) {
      ref.read(isCanvasOpenProvider.notifier).state = false;
    });
  }
}
