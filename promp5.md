Genera el módulo completo de TRANSACCIONES en Flutter con Riverpod y Supabase, integrando con cuentas y categorías. El formulario de agregar transacción debe abrirse en el mismo bottom sheet (canvas) deslizable, con altura adaptativa, cierre por swipe, sobreponiendo el menú. Agrega saldo en tiempo real de la cuenta, cálculos básicos en input de monto con resultado a un lado, y formateo de monto en moneda de la cuenta (pesos default).

Requisitos estrictos:

1. MODELOS:
   - lib/features/transactions/models/transaction_model.dart
     Clase TransactionModel con id, userId, tipo, monto, fecha, estado, descripcion, cuentaOrigenId, cuentaDestinoId, categoriaId, deudaId, metaId, createdAt, updatedAt
     - fromJson / toJson

2. REPOSITORY:
   - lib/features/transactions/data/transactions_repository.dart
     Clase TransactionsRepository con CRUD + realtime channel('transacciones')
     - Al crear: actualiza saldos de cuentas realtime

3. PROVIDERS:
   - lib/features/transactions/presentation/providers/transactions_provider.dart
     - recentTransactionsProvider (StreamProvider<List<TransactionModel>> realtime)
     - transactionFormProvider (StateProvider para estado del form: tipo, monto, etc.)
     - monthlyExpensesProvider (Provider para resumen gastos)

4. WIDGET REUTILIZABLE:
   - lib/features/transactions/presentation/widgets/transaction_tile.dart
     - Card compacta: ícono Ionicons por tipo, descripción + fecha, monto coloreado, botón edit/delete

5. PANTALLAS Y BOTTOM SHEET:
   - lib/features/transactions/presentation/screens/transaction_list_screen.dart (placeholder)
     - Scaffold con AppBar 'Transacciones'
     - ListView con TransactionTile

   - lib/features/transactions/presentation/widgets/transaction_form_sheet.dart (BOTTOM SHEET ÚNICO)
     - showModalBottomSheet(isScrollControlled: true, shape: RoundedRectangleBorder(topLeftRadius: 24, topRightRadius: 24), barrierColor: Colors.black.withOpacity(0.5))
     - DraggableScrollableSheet (initial 0.85, min 0.4, max 0.85, expand: false)
     - Header: "Nueva transacción" + cerrar (Ionicons.close)
     - Contenido: SingleChildScrollView con Column:
       - Segmented control o tabs para tipo (Gastos, Ingresos, Transferencia, etc.) – cambia campos dinámicamente
       - AppTextField monto (numérico, permite cálculos básicos: + - * /, muestra resultado a un lado en Text con animación fade, formatea en real time ej. "$1,234.56 MXN" con intl y moneda de cuenta default)
       - DatePicker fecha (default now)
       - AppTextField descripción
       - Dropdown cuenta origen (fetch cuentas, muestra saldo realtime al lado ej. "Saldo: $1,234.56" con realtime update)
       - Dropdown cuenta destino (si transferencia)
       - Dropdown categoría (fetch según tipo)
       - Dropdown deuda/meta si aplica
     - Bottom: "Cancelar" + "Guardar" (centrados, SizedBox width 120)
     - Altura adaptativa: ajusta a contenido, alinea abajo si corto
     - Cierre: swipe down o botón
     - Sobrepon menú: barrierColor tapa BottomNavigationBar

6. INTEGRACIÓN CON MENÚ:
   - Botón central + del BottomNavigationBar abre este transaction_form_sheet

7. DASHBOARD ACTUALIZADO:
   - Muestra total balance, últimas 5 transacciones (TransactionTile), botón "Nueva transacción" (abre bottom sheet)

8. ESTILO CONSISTENTE:
   - Compacto, padding reducido, radius 12-24
   - Usa AppTextField, AppButton, AppColors, Montserrat, Ionicons
   - Soporte dark mode

Código limpio, comentarios en español.  
Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe el flujo esperado:
- auth → dashboard con nav island
- Botón central + abre bottom sheet transacción
- En bottom sheet: tabs tipo cambian campos, monto con cálculos + resultado a un lado, formateo $1,234.56, saldo cuenta realtime
- Guarda → toast sólido, actualiza saldos
- Canvas sobrepone menú



=== Correcciones ===

Gracias por el módulo de transacciones. Hay tres problemas que necesito corregir urgentemente:

1. La app se traba cuando intento hacer una suma en el campo de monto:
   - El campo de monto permite cálculos básicos (+ - * /), pero cuando escribo expresiones (ej. "100 + 50"), la app se congela o crashea.
   - Corrige el listener o el parser de expresiones para que sea estable: usa un paquete ligero como expressions o eval simple (si es necesario agrega math_expressions), pero evita bucles infinitos o cálculos pesados en cada keystroke.
   - Muestra el resultado calculado a un lado solo cuando la expresión sea válida, de lo contrario muestra el monto crudo sin crash.

2. Los campos de categoría y cuenta origen se ven diferentes al campo de monto:
   - El AppTextField de monto tiene un estilo inconsistente (diferente padding, border, label, formato) respecto a los dropdowns de categoría y cuenta.
   - Haz que todos los campos (monto, categoría, cuenta origen/destino) usen exactamente el mismo estilo base: mismo padding, border radius 12, fillColor de AppColors, labelStyle Montserrat, etc.
   - Asegúrate de que el monto use inputDecorationTheme consistente con AppTextField.

3. El monto no se formatea en tiempo real como moneda MXN:
   - Cuando escribo "15000" en monto, se queda así crudo.
   - Debe formatearse automáticamente mientras escribo (ej. "15,000.00" o "$15,000.00 MXN") usando intl.NumberFormat.currency(locale: 'es_MX', symbol: 'MXN ', decimalDigits: 2)
   - Usa un TextEditingController con listener para reformatear el texto en cada cambio (mantén el valor numérico interno limpio para cálculos).
   - Si hay expresión matemática, muestra el resultado formateado a un lado, pero el campo principal debe seguir mostrando el número formateado.

Aplica estos cambios en transaction_form_sheet.dart (y cualquier archivo relacionado como providers o widgets).  
No cambies nada más del código. Mantén el estilo centralizado con AppTextField, AppButton, AppColors, Montserrat, Ionicons.  
Agrega comentarios en español explicando las correcciones (ej. // Corrección: formateo en tiempo real con intl para evitar crash en cálculos).

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe brevemente cómo quedará después de los cambios:
- Campo monto: formatea en tiempo real como $15,000.00 MXN mientras escribo
- Cálculos básicos (+ - * /) funcionan sin trabarse, resultado mostrado a un lado solo cuando válido
- Todos los campos (monto, categoría, cuenta) tienen estilo idéntico (padding, border, etc.)
- No crash al escribir expresiones matemáticas

=== Fin Correcciones ===



=== Correccion v2 ===

Gracias por el módulo de transacciones. Quiero agregar y ajustar estas funcionalidades importantes para cumplir con las convenciones de planificación financiera:

1. Estado de transacción "Pendiente" vs "Completa":
   - Agrega un selector o toggle en transaction_form_sheet.dart para elegir "Pendiente" o "Completa" (default: "Completa" si fecha <= hoy, "Pendiente" si fecha > hoy)
   - En transaction_model.dart: campo estado ya existe ('completa' o 'pendiente')
   - En transactions_repository.dart (createTransaction y updateTransaction):
     - Si estado == 'pendiente' o fecha > hoy → NO actualiza saldos de cuentas
     - Si estado == 'completa' y fecha <= hoy → SÍ actualiza saldos (resta/suma según tipo)
   - Agrega función en repository o provider para "marcar como completa" (update estado y saldos)

2. Calendario permite fechas futuras:
   - En transaction_form_sheet.dart: DatePicker permite seleccionar fechas mayores a hoy
   - Usa showDatePicker con firstDate: DateTime.now().subtract(Duration(days: 365)), lastDate: DateTime.now().add(Duration(days: 365 * 2))
   - Si fecha > hoy → fuerza estado "Pendiente" (o lo sugiere con mensaje)
   - Las transacciones futuras no afectan balance actual, pero se muestran en sección "Próximos" o "Planificados" (placeholder por ahora)

3. Lógica de impacto en saldos:
   - Transferencias: siempre neutras (resta origen + suma destino) cuando se completan
   - Pagos deuda / Aportes meta: cuentan como gasto (restan de cuenta origen) cuando se completan
   - Ingresos/gastos: suman/restan cuando se completan
   - En dashboard: muestra balance actual (solo transacciones completas con fecha <= hoy) + sección "Próximos pendientes" (transacciones pendientes o futuras)

4. UI en bottom sheet:
   - Agrega un campo o toggle "Estado" (Completa / Pendiente) debajo de la fecha
   - Muestra mensaje sutil si fecha futura: "Se marcará como Pendiente automáticamente"
   - Mantén formato de monto en tiempo real ($15,000.00 MXN), cálculos a un lado, campos dinámicos por tipo

Aplica estos cambios en los archivos afectados (transaction_form_sheet.dart, transaction_model.dart, transactions_repository.dart, transactions_provider.dart, dashboard_screen.dart).  
No cambies nada más del código. Mantén estilo centralizado con AppTextField, AppButton, AppColors, Montserrat, Ionicons.  
Agrega comentarios en español explicando la lógica (ej. // Transacciones pendientes/futuras no afectan saldos hasta completadas).

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe brevemente cómo quedará después de los cambios:
- Al crear transacción con fecha futura o estado "Pendiente" → no modifica saldos actuales
- Al marcar como "Completa" (manual o fecha llega) → actualiza saldos y reportes
- DatePicker permite fechas futuras
- Bottom sheet muestra selector de estado + mensaje de planificación
- Dashboard muestra balance real + placeholder para "Próximos pendientes"

=== Fin Correccion v2 ===


=== Correccion v3 ===

Gracias por el módulo de transacciones. Hay un error al crear transacción: "new row for relation "transacciones" violates check constraint "transacciones_estado_check"". Esto pasa porque el campo 'estado' en la tabla 'transacciones' solo permite 'completa' o 'pendiente', pero el código está enviando null o valor inválido.

Aplica estos ajustes y correcciones en los archivos afectados:

1. Corrección del error de constraint 'transacciones_estado_check':
   - En transaction_model.dart: asegura que 'estado' tenga default 'completa' y nunca sea null
   - En transaction_form_sheet.dart: fuerza estado a 'completa' si fecha <= hoy, o 'pendiente' si fecha > hoy (o usa toggle selector si ya existe)
   - En transactions_repository.dart (createTransaction): siempre envía 'estado': 'completa' o 'pendiente' (nunca null ni otro valor)
   - Agrega validación antes de insert: if (estado == null || !['completa', 'pendiente'].contains(estado)) → estado = 'completa'
   - Agrega comentario: // Corrección: estado siempre 'completa' o 'pendiente' para cumplir CHECK constraint en DB

2. Quitar borde de la sección (probablemente en bottom sheet o container):
   - En transaction_form_sheet.dart: quita cualquier border visible en el Container o Card principal (border: Border.all(width: 0) o shape sin borde)
   - Asegúrate de que el sheet no tenga outline o borde innecesario (shape: RoundedRectangleBorder sin side)

3. Botón central del nav (+):
   - Baja un poco más el FAB central (ajusta margin bottom o alignment en BottomNavigationBar)
   - Hazlo más pequeño: tamaño 56-60 en lugar de grande
   - Mantén fondo teal #0A7075, ícono Ionicons.add_circle_outline, sombra extra

4. Limpieza y reorganización del dashboard (dashboard_screen.dart):
   - Quita botones "Nueva transacción", "Ver cuentas" y "Ver categorías" (ya están en el nav)
   - Organiza así:
     - Sección 1: Tarjetas pequeñas de cuentas (como tarjetas de débito): horizontal scroll o grid, muestra nombre, saldo formateado, tipo (ícono), moneda
     - Sección 2: Listado de transacciones (de futuras a antiguas): ListView con fecha descendente, cada ítem muestra:
       - Categoría (ícono + nombre si existe)
       - Monto coloreado (verde ingreso, rojo gasto)
       - Fecha
       - Toggle estado (Completa/Pendiente) – si toggle a completa, actualiza saldos y toast
       - Descripción en small (Montserrat 12 gray)
     - Usa AppColors para fondos, textos, etc.
   - Mantén AppBar con título 'Dashboard' y settings ícono si aplica

5. Mantén consistencia:
   - Usa AppTextField, AppButton, AppColors, Montserrat, Ionicons
   - Soporte dark mode completo
   - Toasts sólidos (ya generados)

Aplica estos cambios en los archivos afectados (transaction_form_sheet.dart, transactions_repository.dart, dashboard_screen.dart, main.dart o nav).  
No cambies nada más del código. Mantén estilo centralizado. Comentarios en español explicando cada corrección.

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe brevemente cómo quedará después de los cambios:
- Crear transacción: siempre envía 'estado' válido ('completa' o 'pendiente') → no viola constraint
- Bottom sheet sin borde visible en sección principal
- Botón central + más pequeño y un poco más abajo en nav island
- Dashboard limpio: tarjetas de cuentas + listado transacciones (futuras a antiguas) con categoría, monto, fecha, toggle estado, descripción small
- No hay botones extras en dashboard (solo nav)

=== Fin Correccion v3 ===


=== Inicio Correccion v4 ===

Gracias por el módulo de transacciones. Necesito estos ajustes específicos para que funcione como esperábamos:

1. En las transacciones recientes (lista en dashboard o transaction_list_screen.dart): agrega un toggle para el estado (Completa / Pendiente) en cada TransactionTile, que al cambiar actualice el estado en DB y los saldos de cuentas si pasa a 'completa' (usa switch o toggle button estilizado con Ionicons, animación suave).

2. Actualización de montos en cuentas y saldo total al crear/editar transacciones:
   - En transactions_repository.dart (createTransaction/updateTransaction): si estado == 'completa', actualiza saldos de cuentas inmediatamente (resta/suma según tipo, usando realtime)
   - En providers: invalida/refresca totalBalanceProvider y accountsListProvider después de guardar (ref.invalidate)
   - Asegúrate de que el saldo total en dashboard se actualice en tiempo real (realtime subscription o ref.listen)

3. En las cards de transacciones (TransactionTile):
   - Agrega el banco (cuenta origen o destino) con ícono Ionicons.bank o wallet
   - Agrega la categoría con su ícono (Ionicons.fromString(categoria.icono)) y color
   - UI: Row con ícono tipo, descripción, categoría (ícono coloreado + nombre small), cuenta/banco (small), monto coloreado, fecha

4. Botón central de transacciones en el nav:
   - Baja un poco más el FAB central (+) para que se integre mejor al menú (ajusta margin bottom 4-8px, o alignment para que se vea más unido)
   - Hazlo más integrado: reduce tamaño a 52-56, borde radius para que se fusione con el nav island, sombra sutil

5. Tamaño del canvas de transacciones (bottom sheet):
   - En transaction_form_sheet.dart: aumenta initialChildSize: 0.6 → 0.9, maxChildSize: 0.9
   - Mantén minChildSize: 0.4, expand: false, adaptativo al contenido

6. Tipos de transacciones (transferencia, pago de deudas, abono a ahorro):
   - En transaction_form_sheet.dart: agrega opciones al selector de tipo: 'transferencia', 'pago_deuda', 'aporte_meta' (abono a ahorro = 'aporte_meta')
   - UI: segmented o tabs con "Gastos", "Ingresos", "Transferencia", "Pago Deuda", "Abono Ahorro" (cambia campos dinámicamente)
   - Lógica: para 'transferencia' → dropdown origen/destino; para 'pago_deuda' → dropdown deuda; para 'aporte_meta' → dropdown meta

7. Actualización en tiempo real de saldos en el canvas de transacciones:
   - En transaction_form_sheet.dart: el saldo mostrado en dropdown de cuenta origen/destino debe actualizarse en tiempo real (usa StreamProvider o ref.watch(accountsListProvider) con realtime subscription)
   - Al seleccionar cuenta origen → muestra "Saldo: $1,234.56" con animación fade, y actualiza si cambia saldo en background

8. Search en dropdown de categorías para ingresos/gastos:
   - En transaction_form_sheet.dart: cambia DropdownButtonFormField de categoría por un selector con search (TextField búsqueda + ListView filtrado)
   - Filtra por nombre de categoría, muestra ícono coloreado a la derecha
   - Mantén consistente con selector de íconos (altura 90px, childAspectRatio: 1.0, scroll)

Aplica estos cambios en los archivos afectados (transaction_form_sheet.dart, transactions_repository.dart, dashboard_screen.dart, transaction_tile.dart, nav.dart, etc.).
No cambies nada más del código. Mantén el estilo centralizado con AppTextField, AppButton, AppColors, Montserrat, Ionicons, comentarios en español.

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe brevemente cómo quedará después de los cambios:
- Toggle estado en TransactionTile actualiza estado y saldos
- Crear/editar transacción actualiza saldos y total inmediatamente
- TransactionTile muestra cuenta/banco + categoría con ícono/color
- Botón central + más integrado y bajo en nav island
- Bottom sheet transacciones inicial a 0.9 height
- Selector tipo incluye 'transferencia', 'pago_deuda', 'aporte_meta' con UI/ campos dinámicos
- Saldo en dropdown cuenta origen actualiza realtime con animación
- Dropdown categoría con search y ícono/color a la derecha
=== Fin Correccion v4 ===



=== Inicio Correccion v5 ===

Gracias por el módulo de transacciones. Necesito estos ajustes específicos en los archivos ya generados:

1. Opciones de transferencias:
   - En transaction_form_sheet.dart: dentro de la sección "Transferencia" (cuando se selecciona ese tipo), muestra un dropdown o segmented control para elegir el sub-tipo de transferencia (ej. "Entre cuentas", "Pago deuda", "Abono meta") en lugar de tenerlos como tipos principales independientes.
   - Al seleccionar sub-tipo: cambia dinámicamente los campos (origen/destino para entre cuentas, dropdown deuda para pago, dropdown meta para abono).
   - Mantén el mismo bottom sheet, solo cambia contenido interno según sub-tipo.

2. Toggle de estado en transacciones recientes:
   - En transaction_tile.dart (y lista en dashboard): agrega un toggle (Switch o botón estilizado con Ionicons) para cambiar estado entre "Completa" y "Pendiente".
   - Al cambiar a "Completa": actualiza saldos de cuentas (resta/suma según tipo) y muestra toast éxito
   - Al cambiar a "Pendiente": revierte saldos (no cuenta en balance total)
   - Sincroniza con DB vía repository.updateTransaction y ref.invalidate en provider

3. Cards de transacciones más delgadas:
   - En transaction_tile.dart: reduce altura de la card (padding vertical 8 en lugar de 12, font size 14 para descripción, 12 para fecha)
   - Mantén ícono categoría + color, cuenta/banco, monto, toggle estado

4. Quitar botón de agregar transacción en pantalla de transacciones:
   - En transaction_list_screen.dart: elimina FloatingActionButton o AppButton "+ Nueva transacción" (ya está en nav central)

5. Colores en tema dark:
   - En app_theme.dart (darkTheme): ajusta para que sea menos oscuro y más estilizado
     - backgroundDark: Color(0xFF0F0F0F) o #121212 más suave
     - surfaceDark: Color(0xFF1E1E1E) → sube a #252525 o #2A2A2A para contraste
     - textPrimaryDark: #E0E0E0 (gris claro suave)
     - textSecondaryDark: #AAAAAA
     - primary sigue #0A7075 (teal), accent #FF8B6A (coral)
     - Asegúrate de que cards, inputs y nav tengan contraste legible pero elegante

Aplica estos cambios en los archivos afectados (transaction_form_sheet.dart, transaction_tile.dart, transaction_list_screen.dart, app_theme.dart, dashboard_screen.dart).  
No cambies nada más del código. Mantén estilo centralizado con AppColors, AppTheme, Montserrat, Ionicons.  
Agrega comentarios en español explicando cada ajuste (ej. // Ajuste: toggle estado actualiza saldos en tiempo real).

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe brevemente cómo quedará después de los cambios:
- Transferencias: sub-tipos (entre cuentas, pago deuda, abono meta) dentro de una sección con dropdown o segmented
- Toggle en transacciones recientes: cambia estado y actualiza saldos (Completa suma/resta, Pendiente no cuenta)
- Cards de transacciones más delgadas (altura reducida, fuentes small)
- Sin botón + en pantalla de transacciones (solo en nav central)
- Tema dark más estilizado y menos oscuro (fondos #1E1E1E o #252525, textos claros suaves)

=== Fin Correccion v5 ===