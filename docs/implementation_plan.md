# Plan de Implementación de Arquitectura Financiera 🚀

**Fecha de inicio:** Marzo 2026
**Objetivo:** Transformación del proyecto a una Estación de Ingeniería Financiera bajo los parámetros estrictos de integridad de saldos, seguridad de datos e inyección reactiva con Riverpod.

## Estado Actual (Diagnóstico)
1. **Bypasses Detectados:** Existen llamadas directas a `ref.invalidate()` en pantallas como `dashboard_screen.dart`, `category_form_bottom_sheet.dart` y `accounts_list_screen.dart`.
2. **Descentralización del Refresco:** Los repositorios llaman a `refreshAll()` en ocasiones, pero la UI todavía intenta forzar invalidaciones manuales.
3. **Falta de Topología Cleared/Working:** Actualmente el proyecto no diferencia estrictamente entre transacciones 'completas' y 'pendientes' a la hora de advertir al usuario si tiene fondos reales en el dashboard.

## Fase 1: Sellado de Integridad del Estado (Riverpod Logic Expert)
- [x] **Tarea 1.1:** Eliminar TODOS los `ref.invalidate` de pantallas UI (Dashboard, Listas de transacciones, Formularios). La UI es pasiva y solo lee datos.
- [x] **Tarea 1.2:** Consolidar el `FinanceService` (`lib/core/services/finance_service.dart`). Asegurar que `refreshAll()` no solo invalide, sino que garantice la reactividad en cascada de los reducers.
- [x] **Tarea 1.3:** Migración al patrón StreamRiverpod (Listen/Sync) donde el estado se recalcule automáticamente cuando la base de datos subyacente cambie, reduciendo la necesidad del "Refresh All".

## Fase 2: Implementación de Topología Financiera (YNAB Guru)
- [ ] **Tarea 2.1:** Modificar los extractores de saldos para calcular dos variables:
  - `clearedBalance`
  - `workingBalance`
- [ ] **Tarea 2.2:** Actualizar validadores de gasto. Evitar sobregiros si `workingBalance` < `gasto.monto`.
- [x] **Tarea 2.3:** Depurar lógica "Neutral": Transferencias no deben impactar Ingresos y Gastos del mes. Pagos a TC deben ser tratados como Transacciones Neutrales a nivel de liquidez global (una transferencia de Pasivo a Pasivo/Activo).

## Fase 3: Seguridad Backend (Supabase/Backend Lead)
- [ ] **Tarea 3.1:** Crear reglas de base de datos (RLS) enfocadas en asegurar que el `monto_pago` nunca supere el `monto_restante` directamente en un trigger de Supabase.
- [ ] **Tarea 3.2:** Integrar validadores duros en el Repository de Dart.

## Fase 4: Premium Aesthetic Dashboard (UX/UI Designer)
- [ ] **Tarea 4.1:** Aplicar la norma Material 3.
- [ ] **Tarea 4.2:** El Dashboard mostrará explícitamente el Working Balance (Dinero Disponible) como número gigante central.
- [ ] **Tarea 4.3:** Ocultar complejidad; las deudas de tarjetas son una sección "secundaria" para no estresar al usuario, con un botón expansible si requiere el "Detalle Avanzado" documentado en `Logica completa de tarjetas de credito.md`.

## Check-list del Arquitecto 
- [x] Linter `.cursorrules` activo.
- [x] Dominios documentados en `docs/domain_logic.md`.
- [x] Fase de Estabilización Core completada.
- [ ] Refactor del `DashboardScreen` completado.
- [ ] Refactor de Tarjetas (Doble lógica - Mirroring).
