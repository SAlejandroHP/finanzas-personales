# LÓGICA DE LA APP - Finanzas Personal

**Última actualización:** 16 de febrero de 2026  
**Autor:** Alejandro (con apoyo de Grok)  
**Objetivo:** Documentar decisiones clave de lógica financiera, comportamiento de módulos y reglas de negocio para mantener consistencia y evitar errores futuros.

## 1. Principios Generales de la App

- Simplicidad y claridad para usuarios que están aprendiendo a manejar sus finanzas.
- No abrumar con información compleja (intereses, fechas de corte, pago mínimo) en el flujo principal → solo en secciones avanzadas/opcionales.
- Fuente de verdad única: las transacciones reales son la fuente principal para calcular saldos (no los saldos cacheados en cuentas).
- Realtime y consistencia: cualquier cambio (crear, editar, eliminar, cambiar estado) debe reflejarse inmediatamente en todas las pantallas gracias a FinanceService.
- Seguridad en tarjetas de crédito: no se puede pagar más de lo que se debe.
- Todo dentro de contenedores con padding consistente (horizontal 16, vertical 8-12) para evitar elementos pegados a los bordes.

## 2. Convenciones de UX/UI

### Tipografía y colores
- Tipografía principal: Montserrat (via google_fonts)
  - Títulos grandes: bold 20–24
  - Subtítulos: medium 16–18
  - Texto normal: regular 14
  - Texto pequeño: regular 12–13
- Iconografía: Ionicons (paquete ionicons)
  - Tamaño estándar: 24–28 px
- Colores principales (AppColors):
  - Primary: #0A7075 (teal)
  - Accent: #FF8B6A (coral)
  - Gold: #D4AF37
  - Background light: #F5F5F5
  - Background dark: #121212 → #1A1A1A o #252525 (ajustado para no ser tan negro)
  - Surface light: #FFFFFF
  - Surface dark: #252525
  - Text primary light: #333333
  - Text primary dark: #E0E0E0
  - Text secondary: #666666 / #AAAAAA

### Bottom Sheets / Canvas (homogeneidad)
- showModalBottomSheet con:
  - isScrollControlled: true
  - barrierColor: Colors.black.withOpacity(0.5) → tapa el menú inferior
  - shape: RoundedRectangleBorder(topLeftRadius: 24, topRightRadius: 24)
- DraggableScrollableSheet:
  - initialChildSize: 0.85
  - minChildSize: 0.4
  - maxChildSize: 0.85
  - expand: false
- Header: Row con título (Montserrat bold 20) + IconButton cerrar (Ionicons.close)
- Contenido: SingleChildScrollView + Column con padding horizontal 16, vertical 8–12
- Bottom: Row con botones "Cancelar" (text, SizedBox width 120) y "Guardar" (primary, centrados)
- Altura adaptativa: si contenido corto → se queda pequeño y alinea abajo (Spacer o MainAxisAlignment.end)
- Cierre: swipe down o botón cerrar

### Botones y acciones
- AppButton: padding reducido (horizontal 20, vertical 10), radius 12
- Variantes: primary (teal fondo, blanco texto), outlined, text
- FAB central (+): tamaño 56–60, fondo teal, sombra extra, integrado al nav island (no encimado)

### Cards y listas
- Cards: elevation 1–2, radius 12–16, padding vertical 8–10
- TransactionTile: delgada (padding vertical 8), ícono categoría + color, cuenta/banco, descripción small, monto grande coloreado, toggle estado delgado
- Cuentas: cards pequeñas (140–160px ancho) con scroll horizontal en dashboard

### Toasts (SnackBar custom)
- Fondo sólido según tipo (teal éxito #0A7075, coral error #FF8B6A)
- Borde izquierdo width 6 del mismo color
- Ícono pequeño a la izquierda (Ionicons.check_circle_outline, alert_circle_outline)
- Texto Montserrat 14-16 w500, color white
- Posición: floating, margin bottom 80, left/right 16
- Duración: 3 segundos
- Animación: slide up + fade

### Navegación (BottomNavigationBar island)
- Estilo flotante: margen horizontal 16-24, radius 24-32, sombra suave
- Íconos proporcionales (26-28)
- Animación al focus: scale 1.15 + color teal
- Botón central +: integrado (no encimado), tamaño 56-60

## 3. Convenciones Financieras (Reglas de Negocio)
- **Saldo Total Disponible**: suma del `saldo_actual` de todas las cuentas (incluye crédito disponible de tarjetas).
- **Ingresos y Gastos**:
  - Solo se cuentan transacciones con estado **'completa'**.
  - **No tiene nada que ver la fecha**: una transacción 'completa' del año pasado o del futuro **sí afecta** los saldos totales y reportes históricos.
  - Ingresos: suman cuando 'completa' (independientemente de la fecha).
  - Gastos: restan cuando 'completa' (independientemente de la fecha).
  - Transferencias: neutras (resta origen + suma destino, no afectan reportes de ingreso/gasto).
  - Pago de deuda / Aporte a meta: cuentan como gasto (restan de origen cuando 'completa').
- **Pendientes**: no afectan saldos, ingresos ni gastos (aunque la fecha sea pasada o futura) hasta que se marquen 'completa'.
- **Tarjetas de crédito**:
  - Creación: crea cuenta + deuda asociada (monto_total = límite, monto_restante = deuda inicial)
  - Gasto: resta disponible y aumenta deuda restante
  - Pago: suma disponible y reduce deuda restante
  - No se permite pagar más de lo que se debe (ajusta monto + toast)
  - Saldo disponible = límite - deuda restante
  - Se muestra en sección separada "Tarjetas de Crédito"
- **Deudas externas** (préstamos familiares, bancarios, servicios):
  - Se crean manualmente desde Configuración → "Mis Deudas"
  - Pagos: tipo 'pago_deuda' → reduce monto_restante
  - Se muestran en "Deudas Pendientes" en dashboard
- **Transacciones recurrentes** (en progreso):
  - Se guardan como transacciones con is_recurring = true, recurring_rule, next_occurrence
  - No afectan saldos hasta 'completa'
  - Sección en Configuración → "Transacciones Recurrentes"
  - Toggle "Hacer recurrente" en bottom sheet de transacción


## 4. FinanceService (Centralizador de Refrescos)

- Ubicación: lib/core/services/finance_service.dart
- Solo invalida providers después de cualquier operación
- No escribe en BD
- Llamado después de: crear/editar/eliminar transacción, cambiar estado, crear cuenta
FinanceService es el ÚNICO lugar autorizado para coordinar refrescos de datos financieros.

### Reglas obligatorias (no romper nunca):

1. FinanceService NUNCA debe escribir en Supabase (ni update, ni insert, ni delete).
   - Solo invalida providers.

2. Todos los repositorios (transactions_repository, accounts_repository, debts_repository, etc.) deben:
   - Hacer la operación en BD (insert/update/delete)
   - Luego llamar inmediatamente a:
     ref.read(financeServiceProvider).updateAfterTransaction(tx, ref)
     o
     ref.read(financeServiceProvider).refreshAll(ref)

3. En pantallas y widgets (form sheets, tiles, dashboard, etc.):
   - Después de cualquier operación exitosa (guardar, toggle estado, editar cuenta), llamar a:
     ref.read(financeServiceProvider).refreshAll(ref)

4. Proveedores que SIEMPRE deben invalidarse:
   - accountsListProvider
   - totalBalanceProvider
   - monthlyIncomeProvider
   - monthlyExpensesProvider
   - recentTransactionsProvider
   - accountsWithBalanceProvider
   - debtsListProvider (si existe)

5. No inventes nuevas formas de actualizar saldos:
   - Prohibido: actualizar saldo directamente en un provider o pantalla
   - Prohibido: llamar a ref.invalidate manualmente en 5 archivos diferentes
   - Todo pasa por FinanceService

6. Cuando agregues un nuevo provider financiero (ej. budgetsProvider, goalsProvider):
   - Agrégalo a la lista de invalidación en refreshAll()

Si rompes alguna regla → los saldos se desfasan y la app vuelve al caos anterior.

## 5. Dashboard (Estado Actual)

- Saldo Total: suma de saldos disponibles de todas las cuentas
- Sección "Mis Cuentas": todas las cuentas (scroll horizontal)
- Sección "Tarjetas de Crédito": separada
- Transacciones Recientes con toggle de estado  
- Próximos pendientes (placeholder)

## 6. Próximos Pasos Sugeridos

1. Terminar de validar que FinanceService esté siendo llamado en TODOS los lugares
2. Implementar deudas externas (préstamos familiares, bancarios)
3. Agregar sección "Recurrentes" en Configuración
4. Pulir dashboard (sección "Próximos pendientes", visuales)
5. Integración con Belvo (vincular cuentas reales)