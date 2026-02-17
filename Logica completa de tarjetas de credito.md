Genera la lógica completa para tarjetas de crédito, respetando estrictamente la estructura actual del proyecto y manteniendo la simplicidad en el dashboard.

**Lógica requerida (exacta):**

1. Al crear una cuenta de tipo 'tarjeta_credito' (account_form_screen.dart):
   - Crear la cuenta normalmente (tipo = 'tarjeta_credito')
   - Crear automáticamente un registro en la tabla 'deudas':
     - nombre = "Tarjeta " + nombre_cuenta
     - monto_total = límite de crédito (preguntar al usuario en el formulario)
     - monto_restante = límite de crédito
     - cuenta_asociada_id = id de la cuenta recién creada
     - estado = 'activa'

2. Al registrar un gasto con tarjeta de crédito (transaction_form_sheet.dart):
   - Tipo = 'gasto'
   - Cuenta origen = tarjeta
   - Resta del saldo_actual de la tarjeta
   - Resta del monto_restante de la deuda asociada

3. Al registrar un pago a la tarjeta:
   - Tipo = 'pago_deuda'
   - Cuenta origen = cuenta de cheques/efectivo (Banamex, etc.)
   - Deuda asociada = la tarjeta
   - Resta de cuenta origen
   - Suma al saldo_actual de la tarjeta (crédito disponible)
   - Resta del monto_restante de la deuda

4. En dashboard_screen.dart:
   - Sección "Mis Cuentas" (ya existente): mostrar **todas** las cuentas (débito, ahorro, inversión, crédito, etc.) en cards pequeñas con scroll horizontal
   - Al tocar cualquier card → navegar a detalle de cuenta (/accounts/detail/:id)
   - Mantener dashboard limpio y sin saturación

5. Nueva pantalla de detalle de cuenta (lib/features/accounts/presentation/screens/account_detail_screen.dart):
   - AppBar con nombre de la cuenta
   - Información básica: tipo de cuenta (usa getNombreTipoCuenta), saldo actual formateado, moneda
   - Si tipo == 'tarjeta_credito':
     - Sección "Detalles de la tarjeta" (expandible o botón "Ver avanzado"):
       - Límite de crédito
       - Deuda restante
       - Saldo disponible (límite - deuda)
       - Fecha de corte
       - Fecha de pago
       - Pago mínimo
       - Tasa de interés anual (si existe)
       - Consejos educativos simples (Montserrat 14 gray): "Paga antes del corte para evitar intereses", "Evita pagar solo el mínimo", "Mantén bajo tu uso de crédito", etc.
   - Sección "Transacciones de esta cuenta":
     - ListView con transacciones donde cuenta_origen_id o cuenta_destino_id == id de esta cuenta
     - Usa TransactionTile (ya existente) con ícono de categoría + color, cuenta, toggle estado, descripción small
   - Si tipo != 'tarjeta_credito': mostrar placeholder "Detalles de esta cuenta en construcción" + botón "Editar cuenta"

6. Navegación:
   - Agrega ruta en go_router: '/accounts/detail/:id' → AccountDetailScreen(id: params['id'])

Mantén todo en la estructura actual (features/accounts, features/transactions, features/dashboard).  
Usa AppTextField, AppButton, AppColors, Montserrat, Ionicons.  
Código limpio, comentarios en español.  
No agregues nada más (sin recurrentes, sin Belvo por ahora).

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe brevemente cómo quedará después de los cambios:
- Crear tarjeta de crédito → crea cuenta + deuda asociada automáticamente
- Gasto con tarjeta → resta disponible y deuda restante
- Pago desde otra cuenta → suma disponible y resta deuda
- Dashboard: "Mis Cuentas" con scroll horizontal (todas las cuentas) → al tocar → detalle
- Detalle de tarjeta: info básica + sección avanzada con deuda, fechas, pago mínimo, consejos educativos
- Detalle de otras cuentas: placeholder + transacciones de esa cuenta
- Dashboard limpio y funcional



=== Adicion a logica de tarjetas de credito ===


Quiero que en la pantalla de detalle de cuenta (account_detail_screen.dart) se muestre el listado completo de transacciones asociadas a esa cuenta, incluyendo aportes/pagos a la tarjeta de crédito.

Ajustes específicos:

1. En account_detail_screen.dart:
   - Después de la información básica (tipo de cuenta, saldo actual, etc.):
     - Agrega sección "Movimientos de esta cuenta"
     - Título: "Movimientos recientes" (Montserrat bold 18)
     - ListView.builder con transacciones filtradas por cuenta_origen_id == account.id OR cuenta_destino_id == account.id
     - Usa TransactionTile (ya existente) para cada ítem (ícono categoría + color, descripción, monto verde/rojo, fecha, toggle estado, cuenta/banco si aplica)
     - Si vacío: mensaje "No hay movimientos en esta cuenta" (Montserrat 14 gray)
     - Orden: de más reciente a más antigua

2. Si la cuenta es 'tarjeta_credito':
   - Arriba del listado: muestra "Saldo disponible: $X,XXX" y "Deuda total: $X,XXX" (fetch de la deuda asociada)
   - Botón "Ver detalles avanzados" (ya existente) → muestra fecha corte, pago mínimo, tasa interés, consejos

3. Mantén consistencia:
   - Usa AppColors, Montserrat, Ionicons
   - Padding reducido, radius 12-16
   - Soporte dark mode completo
   - Realtime: ref.watch(filteredTransactionsByAccount(accountId)) para actualizar lista

Aplica estos cambios en account_detail_screen.dart y agrega provider filteredTransactionsByAccount si no existe.  
No cambies nada más del código. Mantén estructura centralizada (features/accounts/presentation/screens).

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe brevemente cómo quedará después de los cambios:
- Detalle de cuenta: info básica + listado de movimientos (gastos y pagos/aportes) con TransactionTile
- Para tarjeta de crédito: saldo disponible + deuda total + detalle avanzado
- Movimientos incluyen pagos a la tarjeta (que reducen deuda)
- Todo limpio, funcional y sin saturación


=== Adicional logica de tarjeta 2 ===

Gracias por el módulo de cuentas. Quiero que el formulario de creación de cuenta (account_form_screen.dart) permita registrar tarjetas de crédito ya usadas, con deuda existente.

Ajustes específicos:

1. En account_form_screen.dart:
   - Cuando tipo == 'tarjeta_credito':
     - Agrega AppTextField adicional: "Límite de crédito" (numérico, ej. $8,000)
     - Agrega AppTextField adicional: "Deuda actual / Monto utilizado" (numérico, ej. $7,000, default 0)
     - Muestra mensaje debajo: "El saldo disponible será límite - deuda actual"
   - Al guardar (createAccount):
     - Guarda la cuenta normalmente (tipo 'tarjeta_credito', saldo_actual = límite - deuda_actual)
     - Crea registro en tabla 'deudas':
       - nombre = "Tarjeta " + nombre_cuenta
       - monto_total = límite de crédito
       - monto_restante = deuda actual / monto utilizado
       - cuenta_asociada_id = id de la cuenta recién creada
       - estado = 'activa'
     - Usa transactions_repository o crea accounts_repository si no existe

2. En dashboard y lista de cuentas:
   - Para cuentas tipo 'tarjeta_credito': muestra "Disponible: $X,XXX" (límite - deuda) y "Deuda: $X,XXX" (monto_restante)
   - Mantén cards pequeñas y scroll horizontal

3. Mantén consistencia:
   - Usa AppTextField, AppButton, AppColors, Montserrat, Ionicons
   - No afectes otras cuentas (débito, ahorro, etc.)
   - Soporte dark mode

Aplica estos cambios en account_form_screen.dart, accounts_repository.dart (si no existe, créalo), y dashboard_screen.dart si aplica.  
No cambies nada más del código. Mantén estructura centralizada (features/accounts/presentation/screens, etc.).

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe el flujo esperado:
- Crear cuenta "Tarjeta Nu Crédito" tipo tarjeta_credito
- Ingresa límite $8,000 y deuda actual $7,000
- Guarda → crea cuenta con saldo_actual $1,000 + deuda asociada con monto_restante $7,000
- Dashboard muestra "Disponible: $1,000" y "Deuda: $7,000"
- Al hacer gasto con tarjeta → reduce disponible y deuda
- Al pagar → aumenta disponible y reduce deuda


=== Adicional logica de tarjeta 3 ===

Gracias por el módulo de cuentas. Quiero que el formulario de creación de cuenta (account_form_screen.dart) permita registrar tarjetas de crédito ya usadas, con deuda existente.

Ajustes específicos:

1. En account_form_screen.dart:
   - Cuando tipo == 'tarjeta_credito':
     - Agrega AppTextField adicional: "Límite de crédito" (numérico, ej. $8,000)
     - Agrega AppTextField adicional: "Deuda actual / Monto utilizado" (numérico, ej. $7,000, default 0)
     - Muestra mensaje debajo: "El saldo disponible será límite - deuda actual"
   - Al guardar (createAccount):
     - Guarda la cuenta normalmente (tipo 'tarjeta_credito', saldo_actual = límite - deuda_actual)
     - Crea registro en tabla 'deudas':
       - nombre = "Tarjeta " + nombre_cuenta
       - monto_total = límite de crédito
       - monto_restante = deuda actual / monto utilizado
       - cuenta_asociada_id = id de la cuenta recién creada
       - estado = 'activa'
     - Usa transactions_repository o crea accounts_repository si no existe

2. En dashboard y lista de cuentas:
   - Para cuentas tipo 'tarjeta_credito': muestra "Disponible: $X,XXX" (límite - deuda) y "Deuda: $X,XXX" (monto_restante)
   - Mantén cards pequeñas y scroll horizontal

3. Mantén consistencia:
   - Usa AppTextField, AppButton, AppColors, Montserrat, Ionicons
   - No afectes otras cuentas (débito, ahorro, etc.)
   - Soporte dark mode

Aplica estos cambios en account_form_screen.dart, accounts_repository.dart (si no existe, créalo), y dashboard_screen.dart si aplica.  
No cambies nada más del código. Mantén estructura centralizada (features/accounts/presentation/screens, etc.).

Al final indica correr:
dart run build_runner build --delete-conflicting-outputs && flutter pub get && flutter run

Describe el flujo esperado:
- Crear cuenta "Tarjeta Nu Crédito" tipo tarjeta_credito
- Ingresa límite $8,000 y deuda actual $7,000
- Guarda → crea cuenta con saldo_actual $1,000 + deuda asociada con monto_restante $7,000
- Dashboard muestra "Disponible: $1,000" y "Deuda: $7,000"
- Al hacer gasto con tarjeta → reduce disponible y deuda
- Al pagar → aumenta disponible y reduce deuda

