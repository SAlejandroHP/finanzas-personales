# Checklist del Plan Estratégico: Transacciones Recurrentes y Lectura de Notificaciones

Este documento define el camino técnico para solucionar los Puntos 1 y 2 de "Deuda Técnica y Áreas de Oportunidad" identificados en la auditoría (`auditoria_exhaustiva.md`). La estrategia está alineada con las convenciones definidas en `LOGICA_APP.md` y respeta el flujo estricto del `FinanceService`.

---

## 1. Transacciones Recurrentes

**Objetivo:** Automatizar la creación de transacciones periódicas sin intervención manual, previniendo olvidos y fricción, sin corromper el cálculo de saldos en tiempo real.

### Fase 1: Arquitectura de Base de Datos
- [x] **Crear la tabla `reglas_recurrentes` en Supabase** como satélite para evitar sobrecargar la tabla principal `transacciones`.
- [x] Añadir columna `id` (UUID).
- [x] Añadir columna `user_id` (UUID).
- [x] Añadir columna `plantilla_transaccion` (JSONB) para guardar monto base, categoría, tipo, etc.
- [x] Añadir columna `frecuencia` (String) (ej. `daily`, `weekly`, `monthly`, `yearly`).
- [x] Añadir columna `proxima_ocurrencia` (Timestamp).
- [x] Añadir columna `activa` (Boolean).

### Fase 2: Motor de Ejecución (Supabase Edge Functions + Cron)
- [x] Configurar **pg_cron** o una **Supabase Edge Function** programada (Scheduled Function).
- [x] Escribir la lógica para buscar diariamente a la 01:00 AM las reglas donde `next_occurrence <= NOW()` y `is_active = true`.
- [x] Implementar la inserción de las transacciones generadas en la tabla de transacciones con estado `completa`.
- [x] Asegurar que el sistema actualice automáticamente el valor de `next_occurrence` tras cada inserción basándose en su frecuencia.

### Fase 3: Integración en Flutter (UI & Riverpod)
- [x] **Formulario de Transacción:** Añadir un switch "Hacer recurrente".
- [x] Mostrar un dropdown o selector con opciones de `frequency` cuando se active el switch.
- [x] **Pantalla de Gestión:** Crear la ruta `/settings/recurring` para listar todas las reglas activas.
- [x] Implementar la lógica para pausar, reactivar o eliminar reglas recurrentes desde la pantalla de gestión.
- [x] Validar que al iniciar sesión o realizar pull-to-refresh, el `FinanceService` invoque `refreshAll()` para reflejar los nuevos registros insertados por el cron.

---

## 2. Lectura Automática de Notificaciones Bancarias (Alternativa a Belvo)

**Objetivo:** Interceptar las notificaciones push de aplicaciones bancarias en el dispositivo móvil (Android) para extraer la información de la transacción y registrar el gasto/ingreso automáticamente en la cuenta correspondiente.

### Fase 1: Permisos y Configuración del Servicio (Android)
- [x] Instalar e integrar un paquete como `flutter_notification_listener`.
- [x] Declarar el servicio en el `AndroidManifest.xml` añadiendo el permiso especial `BIND_NOTIFICATION_LISTENER_SERVICE`.
- [x] Crear una sección en "Configuración > Permisos" que guíe o redirija al usuario directamente a la pantalla de ajustes de Android para otorgar el acceso a las notificaciones.

### Fase 2: Servicio en Segundo Plano (Background Isolate)
- [x] Configurar el manejador del paquete dentro de un "isolate" de Dart para que escuche los eventos de notificación en segundo plano y con la app cerrada.
- [x] **Filtro de Aplicaciones:** Declarar un listado de `package_name` válidos correspondientes a bancos (ej. `com.bbva.bbvacontigo`, `com.nu.production`, `com.banamex.mexico`).
- [x] Descartar automáticamente toda notificación cuyo paquete no esté en el listado para ahorrar recursos del dispositivo y preservar la privacidad.

### Fase 3: Motor de Extracción de Datos (Regex + Gemini AI)
- [x] **Nivel 1 (Regex - Rápido):** Construir un diccionario de Expresiones Regulares específicas por banco para capturar el monto (ej. `\$(\d+[\.,]\d{2})`), el comercio/concepto y deducir si es compra o retiro.
- [x] **Nivel 2 (IA - Fallback):** Conectar `google_generative_ai` para recibir el texto de las notificaciones que fallen o sean ambiguas para el Regex.
- [x] Diseñar un prompt estructurado pidiendo exclusivamente un objeto JSON (`{ "amount": X, "is_expense": true, "concept": "Y" }`).
- [x] Relacionar la notificación procesada con el `account_id` específico configurado por el usuario para dicho banco en la app.

### Fase 4: Registro y Finance Service
- [x] Implementar la inserción de las transacciones detectadas con estado **`pendiente` o `por_confirmar`**, para proteger el balance real hasta que el usuario lo revise.
- [x] **Dashboard UI:** Crear un Widget (tarjeta de alerta) que indique "Tienes X nuevos movimientos detectados por validar".
- [x] Diseñar el modal de confirmación al tocar la tarjeta, permitiendo que el usuario confirme el monto, asigne la categoría y la guarde.
- [x] Disparar `ref.read(financeServiceProvider).refreshAll(ref)` inmediatamente después de confirmar para cumplir rigurosamente la regla del proyecto.

---

## 3. Hoja de Ruta Sugerida

- [x] **Hito 1:** Diseñar y desplegar la tabla `recurring_rules` + Edge Function cron. Ajustar UI móvil para habilitar y listar las reglas recurrentes. *(Completado en la Fase 1)*
- [x] **Hito 2:** Implementar el `Notification Listener` nativo en Android, gestionar la pantalla de solicitud de permisos e imprimir en consola las notificaciones bancarias entrantes en background. *(Completado en la Fase 2 - Nota: iOS bloquea la lectura de notificaciones de terceros por diseño del SO, por lo que esto es exclusivo de Android).*
- [x] **Hito 3:** Desarrollar y afinar el Motor de Extracción (Regex y fallback a Gemini AI). *(Completado en la Fase 3)*
- [x] **Hito 4:** Construir y probar la UI de "Gasto por confirmar" en el Dashboard, asegurando la sincronización perfecta con `FinanceService` al aceptarlos. *(Completado en la Fase 4)*
