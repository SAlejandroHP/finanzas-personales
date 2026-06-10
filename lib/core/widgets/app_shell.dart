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
                              // Fondo Liquid Glass del Nav Island
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 24,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.10),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30.0),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isDark 
                                              ? const Color(0xFF1E1E1E).withValues(alpha: 0.45)
                                              : Colors.white.withValues(alpha: 0.40),
                                          border: Border.all(
                                            color: isDark 
                                                ? Colors.white.withValues(alpha: 0.20) 
                                                : Colors.white.withValues(alpha: 0.60),
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(30.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Óvalo indicador de activo integrado al navbar
                              Positioned(
                                left: (animIndex * itemWidth) + 10, // Margen de 10px siempre, garantizando simetría perfecta con el borde exterior (radio 30) y top de 10
                                top: 10, // Centrado verticalmente (60 - 40) / 2
                                child: Container(
                                  width: itemWidth - 20, // Su ancho se adapta dinámicamente para dejar siempre 10px de margen horizontal
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(20), // Forma de óvalo/píldora
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
