Gracias por el módulo anterior. Ahora quiero que lo actualices y completes con estos ajustes finales para que el módulo de cuentas quede pulido, consistente y con los toasts modernos. Sigue exactamente este orden y detalle para evitar errores:

1. MODELOS (crea o actualiza):
   - lib/features/accounts/models/account_model.dart
     Clase AccountModel con:
     - String id
     - String userId
     - String nombre
     - String tipo (solo estos valores: 'efectivo', 'chequera', 'ahorro', 'tarjeta_credito', 'inversion', 'otro')
     - String monedaId
     - double saldoInicial
     - double saldoActual
     - DateTime createdAt
     - DateTime? updatedAt
     - fromJson y toJson métodos

2. REPOSITORY (crea o actualiza):
   - lib/features/accounts/data/accounts_repository.dart
     Clase AccountsRepository con:
     - Future<List<AccountModel>> getUserAccounts()
     - Future<void> createAccount(AccountModel account)
     - Future<void> updateAccount(AccountModel account)
     - Future<void> deleteAccount(String id)
     - Realtime: channel('cuentas').onPostgresChanges para refrescar lista

3. PROVIDERS (crea o actualiza):
   - lib/features/accounts/presentation/providers/accounts_provider.dart
     - accountsListProvider (StreamProvider con realtime)
     - selectedAccountProvider (StateProvider<AccountModel?>)
     - totalBalanceProvider (Provider<double> suma saldos)

4. WIDGET REUTILIZABLE:
   - lib/features/accounts/presentation/widgets/account_card.dart
     - Card (elevation 1, radius 12, padding 12)
     - Row: ícono Ionicons según tipo, nombre (Montserrat bold 16), saldo (Montserrat 18, verde >0, rojo <0, intl.NumberFormat.currency), símbolo moneda, botones edit/delete pequeños

5. PANTALLAS:
   - lib/features/accounts/presentation/screens/accounts_list_screen.dart
     - Usa Scaffold con SafeArea + Padding(horizontal: 16, vertical: 8) en body
     - AppBar: title 'Cuentas'
     - Body: Consumer(accountsListProvider)
       - Loading: Center CircularProgressIndicator
       - Error: Text error
       - Data: ListView.separated con AccountCard
       - Vacío: Center con ícono Ionicons.wallet_outline grande, texto Montserrat "No tienes cuentas", subtítulo "Crea tu primera cuenta para empezar", AppButton "+ Crear cuenta" con padding horizontal 16 vertical 16
     - FloatingActionButton o AppButton inferior para abrir bottom sheet

   - lib/features/accounts/presentation/widgets/account_form_sheet.dart (BOTTOM SHEET)
     - showModalBottomSheet(isScrollControlled: true, shape: RoundedRectangleBorder(topLeftRadius: 24, topRightRadius: 24))
     - DraggableScrollableSheet:
       - initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.85, expand: false
     - Header: Row con título y IconButton cerrar (Ionicons.close)
     - Contenido: SingleChildScrollView con Column (AppTextField nombre, Dropdown tipo, Dropdown moneda fetch desde 'monedas' default MXN, AppTextField saldo inicial numérico con intl)
     - Bottom: Row con AppButton "Cancelar" (text) y "Guardar" (primary)
     - Altura adaptativa: si pocos campos, se queda pequeño y alinea contenido abajo (Spacer o MainAxisAlignment.end)

   - lib/features/dashboard/presentation/screens/dashboard_screen.dart (TEMPORAL)
     - Scaffold con AppBar 'Dashboard'
     - Body: Center con texto "Dashboard en construcción" + AppButton "Ir a Cuentas" → Navigator.pushNamed('/accounts')

6. TOASTS MODERNOS (sin degradado, color sólido):
   - Crea función global showAppToast en lib/core/utils/toast_utils.dart
   - Enum ToastType { success, error, warning, info }
   - Estilo:
     - Success: fondo sólido #0A7075 (teal), borde izquierdo #0A7075 width 6, ícono Ionicons.check_circle_outline blanco
     - Error: fondo sólido #FF8B6A (coral), borde izquierdo #FF8B6A width 6, ícono Ionicons.alert_circle_outline blanco
     - Padding: 16 horizontal, 12 vertical
     - Shape: RoundedRectangleBorder radius 16
     - Sombra: BoxShadow(blurRadius: 8, spreadRadius: 2, offset: Offset(0,4))
     - Texto: Montserrat 14-16 w500, color white
     - Posición: floating, margin bottom 80, left/right 16
     - Duración: 3 segundos
     - Animación: slide up + fade
   - Reemplaza todos los SnackBar actuales por showAppToast(context, message: '...', type: ToastType.success)

7. ESTILO Y CONSISTENCIA:
   - Todas las pantallas envueltas en Padding(horizontal: 16, vertical: 8) + SafeArea
   - Usa AppTextField, AppButton, AppColors, AppTheme (Montserrat, Ionicons)
   - No estilos hardcoded fuera de AppColors/AppTheme

Código limpio, comentarios en español.  
Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe el flujo esperado:
- auth → dashboard temporal → botón a cuentas
- lista con padding correcto y botón "+ Crear cuenta"
- bottom sheet deslizable (altura adaptativa, cierre swipe o botón)
- toast moderno sólido teal con borde izquierdo al crear cuenta