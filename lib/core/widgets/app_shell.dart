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
    // Oculta el FAB cuando el SmartInputBar tiene texto (Punto 2)
    final smartInputHasText = ref.watch(smartInputHasTextProvider);
    final bool showFab = !isCanvasOpen && !smartInputHasText;

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
      floatingActionButton: AnimatedScale(
        scale: showFab ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: showFab ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          child: AnimatedSlide(
            offset: isNavbarVisible ? Offset.zero : const Offset(0, 2),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Transform.translate(
              offset: const Offset(0, -5),
              child: _buildCenterFAB(context, ref),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: !isCanvasOpen
          ? AnimatedSlide(
              offset: isNavbarVisible ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 20), // Recuperados laterales, sin margen inferior
                child: SafeArea(
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Fondo del Nav Island con el "hueco" central
                      CustomPaint(
                        painter: _NotchedIslandPainter(
                          color: isDark 
                              ? AppColors.secondary.withOpacity(0.2) 
                              : AppColors.secondary.withOpacity(0.5),
                          strokeWidth: 3.5,
                        ),
                        child: ClipPath(
                          clipper: _NotchedIslandClipper(),
                          child: Container(
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? AppColors.surfaceDark.withOpacity(0.95) 
                                  : AppColors.surfaceLight.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(32), // Recuperado el radio completo
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildNavButton(context, ref, navItems[0], currentIndex == 0),
                                _buildNavButton(context, ref, navItems[1], currentIndex == 1),
                                const SizedBox(width: 80), // Hueco físico en el Row
                                _buildNavButton(context, ref, navItems[2], currentIndex == 2),
                                _buildNavButton(context, ref, navItems[3], false),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
    return FloatingActionButton(
      onPressed: () => _showAddTransactionSheet(context, ref),
      backgroundColor: AppColors.primary,
      elevation: 0,
      shape: const CircleBorder(),
      child: const Icon(
        Icons.add_rounded,
        size: 32,
        color: Colors.white,
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

/// Clipper personalizado para crear un hueco (notch) en el Nav Island
class _NotchedIslandClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double radius = 32; // Radio de los bordes del container
    final double notchRadius = 38; // Radio del hueco para el FAB
    final double shoulderRadius = 10; // Radio de las orillas del hueco
    final double centerX = size.width / 2;

    path.moveTo(radius, 0);
    
    // Lado izquierdo superior hasta el hombro del notch
    path.lineTo(centerX - notchRadius - shoulderRadius, 0);
    
    // Hombro izquierdo redondeado hacia adentro/abajo
    path.quadraticBezierTo(
      centerX - notchRadius, 
      0, 
      centerX - notchRadius + 4, 
      8,
    );
    
    // El hueco principal (Notch)
    path.arcToPoint(
      Offset(centerX + notchRadius - 4, 8),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    // Hombro derecho redondeado hacia afuera/arriba
    path.quadraticBezierTo(
      centerX + notchRadius, 
      0, 
      centerX + notchRadius + shoulderRadius, 
      0,
    );
    
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(
      Offset(size.width, radius),
      radius: Radius.circular(radius),
    );
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(
      Offset(size.width - radius, size.height),
      radius: Radius.circular(radius),
    );
    path.lineTo(radius, size.height);
    path.arcToPoint(
      Offset(0, size.height - radius),
      radius: Radius.circular(radius),
    );
    path.lineTo(0, radius);
    path.arcToPoint(
      Offset(radius, 0),
      radius: Radius.circular(radius),
    );

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Painter personalizado para dibujar el borde que sigue el notch
class _NotchedIslandPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _NotchedIslandPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final painter = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path();
    final double radius = 32;
    final double notchRadius = 38;
    final double shoulderRadius = 10;
    final double centerX = size.width / 2;

    path.moveTo(radius, 0);
    path.lineTo(centerX - notchRadius - shoulderRadius, 0);
    path.quadraticBezierTo(centerX - notchRadius, 0, centerX - notchRadius + 4, 8);
    path.arcToPoint(Offset(centerX + notchRadius - 4, 8), radius: Radius.circular(notchRadius), clockwise: false);
    path.quadraticBezierTo(centerX + notchRadius, 0, centerX + notchRadius + shoulderRadius, 0);
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius));
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(Offset(size.width - radius, size.height), radius: Radius.circular(radius));
    path.lineTo(radius, size.height);
    path.arcToPoint(Offset(0, size.height - radius), radius: Radius.circular(radius));
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));

    canvas.drawPath(path, painter);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
