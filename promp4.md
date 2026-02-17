Genera el módulo completo de CATEGORÍAS en Flutter con Riverpod y Supabase, y configura la navegación global con BottomNavigationBar en el footer con estilo "island" (como Dock de macOS o neumórfico moderno): barra flotante, margen horizontal 16-24 para no pegarse a los bordes, fondo elevado con sombra suave, bordes redondeados grandes (radius 24-32).

Requisitos estrictos:

1. NAVEGACIÓN GLOBAL (BottomNavigationBar island):
   - Usa go_router (agrega paquete si no existe: flutter pub add go_router)
   - BottomNavigationBar con:
     - Ítems: Dashboard (Ionicons.home_outline), Cuentas (Ionicons.wallet_outline), Categorías (Ionicons.list_outline)
     - En el centro: FAB flotante grande (+) con Ionicons.add_circle_outline, fondo teal #0A7075, sombra extra, siempre visible, abre bottom sheet placeholder para agregar transacción rápida
   - Estilo island:
     - Fondo: AppColors.surface / surfaceDark con opacidad 0.95
     - Margen horizontal: EdgeInsets.symmetric(horizontal: 16-24)
     - Borde redondeado: BorderRadius.circular(24-32)
     - Sombra suave: BoxShadow(blurRadius: 12, spreadRadius: 4, offset: Offset(0, 6))
     - Íconos proporcionales (tamaño 26-28)
     - Animación al focus/selección: scale 1.15, color change a teal #0A7075, duración 200ms
   - CurrentIndex sincronizado con GoRouter location
   - Rutas:
     - '/' → DashboardScreen (home)
     - '/accounts' → AccountsListScreen
     - '/categories' → CategoriesListScreen
     - '/transactions/new' → TransactionFormSheet (placeholder)
   - Actualiza main.dart para usar GoRouter como routerConfig

2. MÓDULO DE CATEGORÍAS (usa el mismo estilo de bottom sheet que en cuentas):
   - Model: lib/features/categories/models/category_model.dart
     - String id, userId, nombre, tipo ('ingreso' o 'gasto'), String? icono (nombre Ionicons ej. 'restaurant_outline'), String? color (hex)
   - Repository: CRUD + realtime channel('categorias')
   - Providers: incomeCategoriesProvider, expenseCategoriesProvider (StreamProvider)
   - Lista: lib/features/categories/presentation/screens/categories_list_screen.dart
     - Scaffold con AppBar 'Categorías'
     - Body: Tabs o segmented Ingresos/Gastos (default Ingresos)
     - ListView con CategoryCard (ícono Ionicons.fromString(icono ?? 'tag_outline'), color del hex, nombre Montserrat bold 16)
     - Vacío: mensaje + AppButton "+ Crear categoría"
     - FloatingActionButton o AppButton inferior para abrir bottom sheet
   - Bottom sheet (canvas) idéntico al de cuentas: lib/features/categories/presentation/widgets/category_form_sheet.dart
     - showModalBottomSheet(isScrollControlled: true, shape: RoundedRectangleBorder(topLeftRadius: 24, topRightRadius: 24), barrierColor: Colors.black.withOpacity(0.5))
     - DraggableScrollableSheet (initial 0.85, min 0.4, max 0.85, expand: false)
     - Header: Row con título ("Nueva categoría" o "Editar categoría") + IconButton cerrar (Ionicons.close)
     - Contenido: SingleChildScrollView con Column:
       - AppTextField nombre
       - Dos divs seleccionables para tipo ("Ingreso" / "Gasto"): Row con dos GestureDetector, Container con borde/fondo teal si activo, texto Montserrat, solo uno seleccionable (sin radio circle visible)
       - Selector de íconos con search: TextField de búsqueda + GridView filtrado (altura 90px, childAspectRatio: 1.0 para una fila visible, scroll para más)
         - Lista inicial de al menos 30 íconos Ionicons comunes (restaurant_outline, cart_outline, car_sport_outline, home_outline, cash_outline, wallet_outline, gift_outline, game_controller_outline, music_note_outline, book_outline, etc.)
         - Al escribir (ej. "cash"), filtra y muestra preview con Icon(IoniconsData.fromString(value)) + texto del nombre
         - Selecciona uno → guarda el nombre exacto (ej. 'cash_outline')
       - Selector de colores visual: Grid de CircleAvatar con 10-15 colores predefinidos (de AppColors o paleta teal/coral/grises), al tap guarda hex
     - Bottom: Row con SizedBox(width: 120) AppButton "Cancelar" + AppButton "Guardar", centrados
     - Altura adaptativa: si pocos campos, se queda pequeño y alinea abajo (Spacer o MainAxisAlignment.end)
     - Cierre: swipe down o botón cerrar
     - Sobrepon el menú: barrierColor opaco tapa el BottomNavigationBar

3. DASHBOARD ACTUALIZADO:
   - Integra como home del BottomNavigationBar
   - Muestra placeholder + botones "Ver cuentas" / "Ver categorías"

4. ESTILO CONSISTENTE:
   - Compacto, padding reducido, radius 12-24
   - Usa AppTextField, AppButton, AppColors, Montserrat, Ionicons
   - Soporte dark mode completo

Código limpio, comentarios en español.  
Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe el flujo esperado:
- auth → dashboard (home con BottomNavigationBar island flotante, margen lateral, íconos proporcionales con animación al focus)
- Botón central + siempre visible para agregar transacción (abre placeholder)
- Clic en Categorías → lista con bottom sheet para crear (selector de íconos con search y preview, selector de colores visual, tipo como divs seleccionables, canvas sobrepone menú)
- Realtime en categorías