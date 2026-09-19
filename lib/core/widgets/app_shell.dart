import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:app_links/app_links.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/ui_provider.dart';
import '../../features/transactions/presentation/widgets/transaction_form_sheet.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/widgets/ai_advisor_bottom_sheet.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/transactions/presentation/screens/transaction_list_screen.dart';
import '../../features/accounts/presentation/screens/accounts_list_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';


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

/// Provider to control main app navigation index (PageView)
final appNavigationProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription? _intentSub;
  StreamSubscription? _appLinksSub;
  bool _isScrolling = false;
  Timer? _scrollTimer;
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initSharingIntentListener();
    _initQuickActions();
    _initAppLinks();
  }

  void _initAppLinks() {
    final appLinks = AppLinks();
    _appLinksSub = appLinks.uriLinkStream.listen((uri) {
      if (uri.host == 'add' || uri.path.contains('add')) {
        ref.read(isCanvasOpenProvider.notifier).state = true;
      }
    });
  }

  void _initQuickActions() {
    const QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_add_transaction') {
        // Open the AI Advisor Bottom Sheet
        ref.read(isCanvasOpenProvider.notifier).state = true;
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_add_transaction',
        localizedTitle: 'Agregar transacción',
        icon: 'AppIcon', // Uses default app icon or system icon if defined natively, but 'compose' is standard iOS, wait, 'AppIcon' or None. We can omit icon or use 'compose' for iOS.
      ),
    ]);
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _appLinksSub?.cancel();
    _scrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _initSharingIntentListener() {
    if (kIsWeb) return; // avoid MissingPluginException on Web

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
    if (files.isEmpty) return;

    SharedMediaFile? imageFile;
    String? textQuery;

    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        textQuery = f.path;
        break;
      }

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

    if (imageFile != null || textQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AIAdvisorBottomSheet(
              initialImagePath: imageFile?.path,
              initialQuery: textQuery,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(appNavigationProvider, (previous, next) {
      if (previous != next && _pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    final isDark       = Theme.of(context).brightness == Brightness.dark;
    
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
        label: 'Cuentas',
        icon: Icons.account_balance_wallet_outlined,
        path: '/accounts',
        index: 2,
      ),
      NavItem(
        label: 'Ajustes',
        icon: Icons.settings_outlined,
        path: '/settings',
        index: 3,
      ),
      NavItem(
        label: 'Agregar',
        icon: Icons.add_circle_outline_rounded,
        path: '', // Abre el modal
        index: 4,
      ),
    ];

    int currentIndex = isCanvasOpen ? 4 : _currentIndex;

    final isNavbarVisible = ref.watch(isNavbarVisibleProvider);
    // Ocultar la barra entera cuando el teclado inteligente esté activo
    final smartInputHasText = ref.watch(smartInputHasTextProvider);
    final bool hideNav = smartInputHasText;

    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          // 1. Ignorar movimientos horizontales (PageView, swiping de pestañas)
          if (scrollNotification.metrics.axis == Axis.horizontal) {
            return false;
          }

          // 2. Detectar la dirección real del scroll vertical
          if (scrollNotification is UserScrollNotification) {
            if (scrollNotification.direction == ScrollDirection.forward) {
              // El usuario hace scroll hacia ARRIBA (viendo contenido anterior)
              // Expandimos la barra inmediatamente
              _scrollTimer?.cancel();
              if (_isScrolling) {
                setState(() => _isScrolling = false);
              }
            } else if (scrollNotification.direction == ScrollDirection.reverse) {
              // El usuario hace scroll hacia ABAJO (viendo contenido nuevo)
              // Encogemos la barra para dar espacio de lectura
              if (!_isScrolling) {
                setState(() => _isScrolling = true);
              }
            }
          } else if (scrollNotification is ScrollEndNotification) {
            // Cuando suelta el dedo y termina la inercia, restaurar después de un delay
            _scrollTimer?.cancel();
            _scrollTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted && _isScrolling) {
                setState(() => _isScrolling = false);
              }
            });
          }
          return false;
        },
        child: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              // Convert PageView index (0,1,2,3) directly to NavItem index (0,1,2,3)
              _currentIndex = index;
            });
            // Keep provider in sync
            Future.microtask(() => ref.read(appNavigationProvider.notifier).state = index);
          },
          children: const [
            DashboardScreen(),
            TransactionListScreen(),
            AccountsListScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: !hideNav
          ? AnimatedSlide(
              offset: isNavbarVisible ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: SafeArea(
                bottom: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: _isScrolling ? 44 : 52, 
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    left: _isScrolling ? 60 : 20, 
                    right: _isScrolling ? 60 : 20, 
                    bottom: bottomMargin + 8.0, 
                  ),
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
                                left: animIndex * itemWidth,
                                top: 0,
                                bottom: 0,
                                width: itemWidth,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    width: _isScrolling ? 40 : 48,
                                    height: _isScrolling ? 32 : 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(_isScrolling ? 16 : 18),
                                    ),
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
                                      currentIndex == item.index,
                                      _isScrolling,
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
    bool isScrolling,
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
            // Because Agregar is at index 4, any other item index matches the page index exactly
            _pageController.animateToPage(
              item.index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
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
                child: AnimatedScale(
                  scale: isScrolling ? 0.85 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    item.icon,
                    size: 24, // El tamaño base se escala suavemente
                    color: isActive 
                        ? Colors.white 
                        : (isDark ? Colors.white54 : Colors.grey[600]),
                  ),
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
