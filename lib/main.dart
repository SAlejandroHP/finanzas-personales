import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_colors.dart';
import 'core/network/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'core/providers/ui_provider.dart';
import 'features/auth/presentation/screens/auth_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/dashboard/presentation/screens/notifications_screen.dart';
import 'features/accounts/presentation/screens/accounts_list_screen.dart';
import 'features/accounts/presentation/screens/account_detail_screen.dart';
import 'features/categories/presentation/screens/categories_list_screen.dart';
import 'features/transactions/presentation/screens/transaction_list_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/debts/presentation/screens/debts_list_screen.dart';
import 'features/goals/presentation/screens/goals_list_screen.dart';


/// ==============================================================
/// GUÍA PARA PREPARAR LA APP PARA TESTFLIGHT (iOS)
/// ==============================================================
///
/// 1. CONFIGURACIÓN PREVIA:
///    - Bundle ID: Asegúrate de que en ios/Runner/Info.plist el CFBundleIdentifier
///      sea "com.alejandro.finanzas" o similar (debe coincidir con el en App Store Connect)
///    - Team ID: Configura el Team ID en Xcode (selecciona Runner → Signing & Capabilities)
///    - Certificados: Descarga los certificados de Apple Developer (iOS Development y Distribution)
///
/// 2. PERMISOS REQUERIDOS (iOS/Info.plist):
///    - Face ID / Touch ID: <key>NSFaceIDUsageDescription</key>
///      <string>Se utiliza para autenticar tu cuenta de forma segura</string>
///    - Google Sign-In: <key>LSApplicationQueriesSchemes</key> (ya está configurado)
///    - Acceso a datos: Asegúrate de incluir el Privacy Policy URL en la App Store
///
/// 3. COMPILAR PARA iOS RELEASE:
///    > flutter clean
///    > flutter pub get
///    > flutter build ipa --release
///
///    NOTA: En caso de error, limpia derivados:
///    > cd ios && rm -rf Pods Podfile.lock .symlinks/ Flutter/Flutter.framework Flutter/Flutter.podspec && cd ..
///    > flutter pub get
///    > flutter build ipa --release
///
/// 4. UPLOADEAR A TESTFLIGHT:
///    a) Abre Xcode:
///       > open ios/Runner.xcworkspace
///
///    b) En Xcode:
///       - Selecciona "Runner" en el Project Navigator (izquierda)
///       - Tab "Build Settings"
///       - Busca "Code Signing Identity" → asegúrate de que sea "iPhone Distribution"
///       - Tab "Signing & Capabilities" → verifica Team ID
///
///    c) Archiva la app:
///       - Product → Scheme → selecciona "Runner"
///       - Product → Archive
///       - Espera a que termine la compilación
///
///    d) En el Organizer:
///       - Distribuye la app: Distribute App → App Store Connect → Upload
///       - Selecciona el nombre de la app, versión y build
///       - Elige "Automatically manage signing"
///       - Upload
///
/// 5. EN APP STORE CONNECT:
///    - Ve a TestFlight → [Tu App]
///    - Espera a que Apple procese la build (5-30 min)
///    - Agrega testers internos (tu email) en Users and Access
///    - Acepta la invitación en TestFlight (iOS)
///    - Descarga la app y prueba
///
/// 6. RELEASE NOTES:
///    - Actualiza las notas de la versión antes de enviar a TestFlight
///    - Escribe un resumen de los cambios principales
///
/// 7. TROUBLESHOOTING:
///    - "Provisioning Profile": Crea uno nuevo en Apple Developer → Certificates, Identifiers & Profiles
///    - "Code Signing Error": Limpia Derived Data: Xcode → Settings → Locations → Derived Data (click arrow)
///    - "App Crashes": Revisa los logs en TestFlight → [App] → Activity → Build → View on App Store Connect
///
/// ==============================================================


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializa formateo de fechas en español
  await initializeDateFormatting('es', null);
  
  // Inicializa Supabase
  await initSupabase();

  // Inicializa SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtiene el modo de tema del provider
    final themeModeValue = ref.watch(themeModeProvider);
    
    // Convierte el enum AppThemeMode personalizado a ThemeMode de Flutter
    final flutterThemeMode = switch(themeModeValue) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Finanzas App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: flutterThemeMode,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Provider para el GoRouter que persiste el estado de navegación
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) => _handleRedirects(context, state),
    routes: [
      // Shell route con el BottomNavigationBar
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          // Dashboard (home)
          GoRoute(
            path: '/',
            name: 'dashboard',
            pageBuilder: (context, state) => _fadeTransitionPage(
              state: state,
              child: const DashboardScreen(),
            ),
          ),
          // Cuentas
          GoRoute(
            path: '/accounts',
            name: 'accounts',
            pageBuilder: (context, state) => _fadeTransitionPage(
              state: state,
              child: const AccountsListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'detail/:id',
                name: 'account_detail',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return _fadeTransitionPage(
                    state: state,
                    child: AccountDetailScreen(accountId: id),
                  );
                },
              ),
            ],
          ),
          // Transacciones
          GoRoute(
            path: '/transactions',
            name: 'transactions',
            pageBuilder: (context, state) => _fadeTransitionPage(
              state: state,
              child: const TransactionListScreen(),
            ),
          ),
          // Metas
          GoRoute(
            path: '/goals',
            name: 'goals',
            pageBuilder: (context, state) => _fadeTransitionPage(
              state: state,
              child: const GoalsListScreen(),
            ),
          ),
          // Categorías
          GoRoute(
            path: '/categories',
            name: 'categories',
            pageBuilder: (context, state) => _fadeTransitionPage(
              state: state,
              child: const CategoriesListScreen(),
            ),
          ),
          // Configuración
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => _fadeTransitionPage(
              state: state,
              child: const SettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'debts',
                name: 'debts',
                pageBuilder: (context, state) => _fadeTransitionPage(
                  state: state,
                  child: const DebtsListScreen(),
                ),
              ),
            ],
          ),
          // Notificaciones
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            pageBuilder: (context, state) => _fadeTransitionPage(
              state: state,
              child: const NotificationsScreen(),
            ),
          ),
        ],
      ),
      // Auth
      GoRoute(
        path: '/auth',
        name: 'auth',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const AuthScreen(),
        ),
      ),
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _fadeTransitionPage(
          state: state,
          child: const SplashScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Página no encontrada',
                style: GoogleFonts.montserrat(
                  fontSize: AppColors.titleMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      );
    },
  );
});

/// Helper para crear transiciones suaves de tipo fade (desvanecimiento)
/// Este tipo de transición es más fluida en la web que el desplazamiento lateral nativo.
CustomTransitionPage _fadeTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
  );
}

/// Maneja los redirects al cambiar rutas
Future<String?> _handleRedirects(
  BuildContext context,
  GoRouterState state,
) async {
  final routeName = state.name;
  
  // Si ya estamos en splash o auth, no redirige
  if (routeName == 'splash' || routeName == 'auth') {
    return null;
  }

  // Verifica autenticación
  final isSigned = supabaseClient.auth.currentUser != null;

  // Si no hay usuario y no está en auth, redirige a auth
  if (!isSigned) {
    return '/auth';
  }

  // Si hay usuario, permite acceso
  return null;
}

/// SplashScreen mejorada con degradado teal y animaciones
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  int _messageIndex = 0;
  final List<String> _messages = [
    'Inicializando...',
    'Cargando datos...',
    'Preparando tu experiencia...',
    'Casi listo...',
  ];

  @override
  void initState() {
    super.initState();
    
    // Animación de fade-in
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _animationController.forward();
    
    // Cambia el mensaje cada 500ms
    _rotateMessages();
    
    // Espera mínimo 2 segundos antes de verificar auth
    _checkAuthAndNavigate();
  }

  void _rotateMessages() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
        if (_messageIndex != 0) {
          _rotateMessages();
        }
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    // Espera mínimo 2 segundos para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Verifica si hay un usuario autenticado
    final currentUser = supabaseClient.auth.currentUser;
    
    if (currentUser != null) {
      // Usuario autenticado, va al dashboard
      if (mounted) {
        context.go('/');
      }
    } else {
      // Sin usuario, va a autenticación
      if (mounted) {
        context.go('/auth');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A7075), Color(0xFF0D9BA1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono de wallet con animación
                const Icon(
                  Icons.account_balance_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                
                // Título
                Text(
                  'Finanzas Personal',
                  style: GoogleFonts.montserrat(
                    fontSize  : 36,
                    fontWeight: FontWeight.w700,
                    color     : Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Indicador de carga
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Mensaje cambiante
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _messages[_messageIndex],
                    key: ValueKey<int>(_messageIndex),
                    style: GoogleFonts.montserrat(
                      fontSize: AppColors.bodyMedium,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
