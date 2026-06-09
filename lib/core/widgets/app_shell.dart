import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/ui_provider.dart';
import '../../features/transactions/presentation/widgets/transaction_form_sheet.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/widgets/ai_advisor_bottom_sheet.dart';

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
class AppShell extends ConsumerStatefulWidget {
  /// Pantalla actual a mostrar
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription? _intentSub;

  @override
  void initState() {
    super.initState();
    _initSharingIntentListener();
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  void _initSharingIntentListener() {
    // 1. Escuchar cuando la app está en segundo plano y recibe una imagen compartida
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
      }
    }, onError: (err) {
      debugPrint("Error al escuchar intenciones compartidas: $err");
    });

    // 2. Escuchar cuando la app se abre de cero compartiendo la imagen
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
      }
      ReceiveSharingIntent.instance.reset();
    }).catchError((err) {
      debugPrint("Error al obtener intención compartida inicial: $err");
    });
  }

  void _handleSharedMedia(List<SharedMediaFile> files) {
    SharedMediaFile? imageFile;
    for (final f in files) {
      final path = f.path.toLowerCase();
      if (path.endsWith('.png') ||
          path.endsWith('.jpg') ||
          path.endsWith('.jpeg') ||
          path.endsWith('.heic') ||
          path.endsWith('.webp')) {
        imageFile = f;
        break;
      }
    }

    if (imageFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          /*
          showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AIAdvisorBottomSheet(
              initialImagePath: imageFile!.path,
            ),
          );
          */
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final location = GoRouterState.of(context).matchedLocation;
    
    // Detección de PWA vs Nativa (kIsWeb detecta si corre en navegador)
    final bool isPwa = kIsWeb;
    final double bottomMargin = isPwa ? AppColors.pagePadding : 0.0;
    
    final isCanvasOpen = ref.watch(isCanvasOpenProvider);

    // Ítems de navegación con "Agregar" como opción
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
        label: 'Agregar',
        icon: Icons.add_circle_outline_rounded,
        path: '', // Abre el modal
        index: 2,
      ),
      NavItem(
        label: 'Configuración',
        icon: Icons.settings_outlined,
        path: '/settings',
        index: 3,
      ),
      NavItem(
        label: 'Salir',
        icon: Icons.logout_outlined,
        path: '', // Dispara acción
        index: 4,
      ),
    ];

    int currentIndex = 0;
    if (isCanvasOpen) {
      currentIndex = 2; // El notch se desliza al centro si el modal está abierto
    } else if (location.startsWith('/transactions')) {
      currentIndex = 1;
    } else if (location.startsWith('/settings') || 
               location.startsWith('/accounts') || 
               location.startsWith('/categories')) {
      currentIndex = 3;
    }

    final isNavbarVisible = ref.watch(isNavbarVisibleProvider);
    // Ocultar la barra entera cuando el teclado inteligente esté activo
    final smartInputHasText = ref.watch(smartInputHasTextProvider);
    final bool hideNav = smartInputHasText;

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: !hideNav
          ? AnimatedSlide(
              offset: isNavbarVisible ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                height: 60, // Aumentado
                width: double.infinity,
                margin: EdgeInsets.only(
                  left: 20, 
                  right: 20, 
                  bottom: bottomMargin + AppColors.pagePadding, 
                ),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double itemWidth = constraints.maxWidth / navItems.length;
                      
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: currentIndex.toDouble()),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.fastOutSlowIn,
                        builder: (context, animIndex, child) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Fondo del Nav Island con el hueco central móvil
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _CurvedBarPainter(
                                    index: animIndex,
                                    itemWidth: itemWidth,
                                    color: isDark 
                                        ? AppColors.surfaceDark.withOpacity(0.95) 
                                        : AppColors.surfaceLight.withOpacity(0.95),
                                  ),
                                ),
                              ),
                              // Círculo indicador de activo integrado al navbar
                              Positioned(
                                left: (animIndex * itemWidth) + (itemWidth / 2) - 24,
                                top: 6, // Centrado verticalmente (60 - 48) / 2
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    // Sombra eliminada de las opciones
                                  ),
                                ),
                              ),
                              // Fila de botones de navegación
                              Positioned.fill(
                                child: Row(
                                  children: navItems.map((item) {
                                    return _buildNavButton(
                                      context, 
                                      ref, 
                                      item, 
                                      currentIndex == item.index
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            )
          : null,
    );
  }

  /// Construye un botón de navegación con animación (Sin labels)
  Widget _buildNavButton(
    BuildContext context,
    WidgetRef ref,
    NavItem item,
    bool isActive,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (item.label == 'Salir') {
            _showLogoutConfirmation(context, ref);
          } else if (item.label == 'Agregar') {
            _showAddTransactionSheet(context, ref);
          } else {
            context.go(item.path);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            // Icon - Centrado en todo momento
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.fastOutSlowIn,
              top: 0.0,
              bottom: 0.0,
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  item.icon,
                  size: 26,
                  color: isActive 
                      ? Colors.white 
                      : (isDark ? Colors.white54 : Colors.grey[600]),
                ),
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

  /// Muestra un bottom sheet para agregar transacción
  void _showAddTransactionSheet(BuildContext context, WidgetRef ref) {
    ref.read(isCanvasOpenProvider.notifier).state = true;
    showTransactionFormSheet(context).then((_) {
      ref.read(isCanvasOpenProvider.notifier).state = false;
    });
  }
}

class _CurvedBarPainter extends CustomPainter {
  final double index;
  final double itemWidth;
  final Color color;

  _CurvedBarPainter({
    required this.index,
    required this.itemWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Sombra principal fuerte
    final dropShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.20) // Sombra más oscura para destacar la barra
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      
    // Sombra ambiental suave
    final ambientShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    // 1. Base shape
    final RRect hostRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(30.0), // Radio aumentado a 30 (píldora completa) para coincidir con las opciones
    );
    final Path hostPath = Path()..addRRect(hostRRect);

    // 2. Exact center of the current selected notch/bump
    final double notchCenter = (index * itemWidth) + (itemWidth / 2);

    double clampX(double x) => x < 0 ? 0 : (x > size.width ? size.width : x);

    // 3. Crear el path de la "jorobita" (pansita)
    final Path bumpPath = Path();
    // Empezamos profundo y clampado a los bordes para fusionarse suavemente con las esquinas
    bumpPath.moveTo(clampX(notchCenter - 40), 30); 
    
    // Curva sutil y ancha sobre el círculo
    bumpPath.cubicTo(
      clampX(notchCenter - 28), 10,   
      clampX(notchCenter - 26), -4,   
      notchCenter, -4,        
    );
    
    // Curva de bajada
    bumpPath.cubicTo(
      clampX(notchCenter + 26), -4,
      clampX(notchCenter + 28), 10,
      clampX(notchCenter + 40), 30,
    );
    
    bumpPath.close(); // Se cierra a lo largo de y=30

    // 4. Unir la jorobita al rectángulo principal
    final Path finalPath = Path.combine(
      PathOperation.union,
      hostPath,
      bumpPath,
    );

    // Shadow
    canvas.save();
    // Ambient Shadow (centrada)
    canvas.drawPath(finalPath, ambientShadowPaint);
    // Drop Shadow (hacia abajo)
    canvas.translate(0, 6);
    canvas.drawPath(finalPath, dropShadowPaint);
    canvas.restore();

    // Solid bar
    canvas.drawPath(finalPath, paint);
    
    // Subtle border
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawPath(finalPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedBarPainter oldDelegate) {
    return oldDelegate.index != index || 
           oldDelegate.itemWidth != itemWidth ||
           oldDelegate.color != color;
  }
}
