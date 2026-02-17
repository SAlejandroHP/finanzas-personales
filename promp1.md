Crea la estructura inicial de carpetas y archivos base para una app Flutter de finanzas personales con Riverpod 2.x y Supabase.

Usa exactamente esta estructura:

lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   └── app_sizes.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── extensions.dart
│   ├── network/
│   │   └── supabase_client.dart
│   └── widgets/
│       ├── app_button.dart
│       └── loading_indicator.dart
├── features/
│   └── auth/               # solo crea la carpeta vacía por ahora
├── shared/
│   └── models/
│       └── user_model.dart # modelo básico de usuario
└── main.dart

Requisitos específicos:

1. Tipografía principal: Montserrat (carga con google_fonts, usa Montserrat como fontFamily default en ThemeData).

2. Iconografía: Usa el paquete ionicons para todos los íconos de la app (Ionicons).

3. Framework UI: Material 3 completo (useMaterial3: true en ThemeData).

4. Colores en app_colors.dart:
   const primaryTeal     = Color(0xFF0A7075);
   const accentCoral     = Color(0xFFFF8B6A);
   const gold            = Color(0xFFD4AF37);
   const backgroundLight = Color(0xFFF5F5F5);
   const textDark        = Color(0xFF333333);
   const textLight       = Color(0xFFFFFFFF);

5. En app_theme.dart:
   - ThemeData.light() y dark() con Material 3
   - colorScheme basado en primaryTeal (seedColor: primaryTeal)
   - fontFamily: 'Montserrat'
   - Usa google_fonts para cargar Montserrat
   - Soporte completo para ThemeMode.system

6. En supabase_client.dart:
   - Inicializa Supabase con:
     final supabase = Supabase.instance.client;
   - Constantes comentadas:
     const supabaseUrl = 'https://txaikgsomwstkfcwfeov.supabase.co';
     const supabaseAnonKey = 'sb_publishable_nI-YWJokAyCWo9wHBWqaNw_dAWyjVpV';

7. En main.dart:
   - ProviderScope de Riverpod
   - MaterialApp.router o MaterialApp con theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: ThemeMode.system
   - home: const SplashScreen() (placeholder simple con texto "Cargando..." y CircularProgressIndicator)

8. En shared/models/user_model.dart: clase simple UserModel con id (String), email (String?), fullName (String?), avatarUrl (String?).

Agrega en comentarios al inicio del archivo o en un comentario separado las dependencias necesarias para pubspec.yaml:

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  supabase_flutter: ^2.8.1
  google_fonts: ^6.2.1
  ionicons: ^0.2.3  # o la versión más reciente
  flutter_secure_storage: ^9.2.2
  fl_chart: ^0.68.0
  intl: ^0.19.0
  uuid: ^4.5.0

dev_dependencies:
  build_runner: ^2.4.13
  riverpod_generator: ^2.4.3

Código limpio, bien comentado en español, imports correctos, sin errores de sintaxis.