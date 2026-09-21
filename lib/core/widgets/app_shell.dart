import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  StreamSubscription? _intentSub;
  StreamSubscription? _appLinksSub;
  bool _isScrolling = false;
  bool _isTappingNav = false;
  late final PageController _pageController;
  int _currentIndex = 0;

  ImageProvider? _cachedAvatarProvider;
  String? _lastAvatarUrl;

  ImageProvider? _getAvatarProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url == _lastAvatarUrl && _cachedAvatarProvider != null) {
      return _cachedAvatarProvider;
    }
    _lastAvatarUrl = url;
    if (url.startsWith('http')) {
      _cachedAvatarProvider = NetworkImage(url);
    } else {
      try {
        _cachedAvatarProvider = MemoryImage(base64Decode(url.split(',').last));
      } catch (e) {
        _cachedAvatarProvider = null;
      }
    }
    return _cachedAvatarProvider;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initSharingIntentListener();
    _initQuickActions();
    _initAppLinks();
  WidgetsBinding.instance.addObserver(this);
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
    if (kIsWeb) return;
    try {
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
    } catch (e) {
      debugPrint('Error initializing QuickActions: $e');
    }
  }

  @override
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isScrolling) {
        setState(() => _isScrolling = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentSub?.cancel();
    _appLinksSub?.cancel();
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
        // Only animate if the controller isn't already at this page (e.g., from jumpToPage or swiping)
        if (_pageController.page?.round() != next) {
          _pageController.jumpToPage(next);
        }
      }
    });

    final isDark       = Theme.of(context).brightness == Brightness.dark;
    
    // Detección de PWA vs Nativa (kIsWeb detecta si corre en navegador)
    final bool isPwa = kIsWeb;
    final double bottomMargin = isPwa ? AppColors.pagePadding : 0.0;
    
    final isCanvasOpen = ref.watch(isCanvasOpenProvider);
    final userAsync = ref.watch(currentUserProvider);
    final avatarUrl = userAsync.value?.userMetadata?['avatar_url'] as String?;

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
    // Ocultar la barra entera cuando el teclado esté abierto para que no flote arriba
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool hideNav = isKeyboardOpen;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          // Switch back to dashboard instead of exiting
          ref.read(appNavigationProvider.notifier).state = 0;
        } else {
          // We are on dashboard. We can exit.
          // SystemNavigator.pop() exits the app on Android.
          // However, GoRouter handles root back presses differently.
          // To allow normal exit on Android when at index 0, we can use SystemNavigator:
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: NotificationListener<ScrollNotification>(
          onNotification: (scrollNotification) {
          // 1. Ignorar movimientos horizontales (PageView, swiping de pestañas)
          if (scrollNotification.metrics.axis == Axis.horizontal) {
            return false;
          }

          // 2. Detectar la dirección real del scroll vertical
          if (scrollNotification is UserScrollNotification) {
            if (scrollNotification.direction == ScrollDirection.reverse) {
              if (!_isScrolling) setState(() => _isScrolling = true);
            } else if (scrollNotification.direction == ScrollDirection.forward) {
              if (_isScrolling) setState(() => _isScrolling = false);
            }
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
            _KeepAlivePage(child: DashboardScreen()),
            _KeepAlivePage(child: TransactionListScreen()),
            _KeepAlivePage(child: AccountsListScreen()),
            _KeepAlivePage(child: SettingsNavigator()),
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
                  height: _isScrolling ? 56 : 64, 
                  width: double.infinity,
                  margin: EdgeInsets.only(
                    left: _isScrolling ? 40 : 16, 
                    right: _isScrolling ? 40 : 16, 
                    bottom: bottomMargin, // Se redujo el margen inferior extra para bajar el nav
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double itemWidth = constraints.maxWidth / navItems.length;
                      
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double pageValue = 0.0;
                          if (_pageController.hasClients && _pageController.position.haveDimensions) {
                            pageValue = _pageController.page ?? _currentIndex.toDouble();
                          } else {
                            pageValue = _currentIndex.toDouble();
                          }
                          
                          bool forceAnimation = isCanvasOpen || (currentIndex == 4) || _isTappingNav;
                          double animIndex = isCanvasOpen ? 4.0 : pageValue;
                          
                          // Agregamos padding horizontal al interior del nav para que el primer
                          // y último ícono no choquen con la curvatura del borde (borderRadius: 30)
                          const double horizontalPadding = 8.0;
                          final double availableWidth = constraints.maxWidth - (horizontalPadding * 2);
                          final double itemWidth = availableWidth / navItems.length;
                          
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
                                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
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
                              AnimatedPositioned(
                                duration: forceAnimation ? const Duration(milliseconds: 300) : Duration.zero,
                                curve: Curves.easeOutCubic,
                                left: horizontalPadding + (animIndex * itemWidth),
                                top: 0,
                                bottom: 0,
                                width: itemWidth,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    width: _isScrolling ? 46 : 56, // Reducido para que no choque con los bordes
                                    height: _isScrolling ? 38 : 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(_isScrolling ? 19 : 23),
                                    ),
                                  ),
                                ),
                              ),
                              // Fila de botones de navegación
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                                  child: Row(
                                  children: navItems.map((item) {
                                    // Make the icon light up smoothly if it's currently selected
                                    bool isIconActive = (item.index == 4 && isCanvasOpen) || (!isCanvasOpen && _currentIndex == item.index);
                                    return _buildNavButton(
                                      context, 
                                      ref, 
                                      item, 
                                      isIconActive,
                                      _isScrolling,
                                      avatarUrl,
                                    );
                                  }).toList(),
                                  ),
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
      ),
    );
  }

  /// Construye un botón de navegación con animación (Sin labels)
  Widget _buildNavButton(
    BuildContext context,
    WidgetRef ref,
    NavItem item,
    bool isActive,
    bool isScrolling,
    String? avatarUrl,
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
            // Animamos el botón de la navbar manualmente
            setState(() {
              _isTappingNav = true;
            });
            
            // Siempre usamos jumpToPage para que las pantallas cambien instantáneamente
            // sin el efecto de "carrusel", mientras el AnimatedPositioned de la barra hace el slide fluido.
            _pageController.jumpToPage(item.index);
            
            // Restablecemos la bandera después de la animación
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _isTappingNav = false;
                });
              }
            });
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
                  child: (item.label == 'Ajustes' && _getAvatarProvider(avatarUrl) != null)
                      ? Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? Colors.white : Colors.transparent,
                              width: isActive ? 1.5 : 0,
                            ),
                            image: DecorationImage(
                              image: _getAvatarProvider(avatarUrl)!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Icon(
                          item.icon,
                          size: 28, // Proporciones de Instagram Island
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

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
