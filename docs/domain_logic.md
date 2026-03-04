# Lógica de Dominio y Core Financiero

**Última actualización:** 2 de marzo de 2026
**Autor:** Director de Ingeniería Financiera (Antigravity)

**Objetivo:** Este documento define la fundamentación teórica y arquitectónica del motor financiero de la aplicación. Cualquier regla de negocio, cálculo de saldo o registro de transacciones debe alinearse estrictamente a estos principios. No es sugerencia, es la ley del sistema.

## 1. Topología de Saldos: Cleared vs. Working Balance
Para evitar el "hackeo" de la liquidez percibida y proteger financieramente al usuario, se implementa una topología de doble saldo inspirada en mejores prácticas financieras (tipo YNAB):

- **Cleared Balance (Saldo Conciliado):**
  Es el dinero que el banco ya confirmó. Se calcula sumando TODAS las transacciones cuyo estado es `completa` (o `cleared`). Este es el saldo oficial, pero **NO** es el saldo en el que el usuario debe basar sus decisiones de gasto diario.
  
- **Working Balance (Saldo Disponible/Real):**
  Es el "Cleared Balance" ajustado por todas las transacciones `pendientes`. Si el usuario registra un gasto futuro o un cheque no cobrado, este monto se resta inmediatamente del Working Balance. 
  *Regla de Oro:* **Las decisiones de UX y advertencias de fondos insuficientes se basan SIEMPRE en el Working Balance.**

## 2. Transacciones Neutrales
No todas las transacciones afectan el patrimonio neto (Net Worth). Existen movimientos de reubicación de capital:
- **Transferencias Internas:** Mover $100 de "Cuenta Débito" a "Ahorro" genera un evento dual (+100 y -100). Para el sistema de reportes de Ingresos/Gastos, estos movimientos son **Neutrales**. No son gastos, no son ingresos.
- **Pagos a Tarjetas de Crédito:** Un pago a la TC desde la cuenta de Débito reduce la liquidez (Working Balance de débito) pero también reduce el pasivo (mide la misma cantidad en la Deuda Restante de la TC). El Net Worth se mantiene neutral (el pasivo disminuye en la misma proporción que el activo).

## 3. Lógica Mirror (Mecanismo de Doble Entrada Simplificado)
Para mantener la consistencia e integridad de los datos, ciertas operaciones requieren Lógica Mirror:
- **Transacciones de Transferencia:** En lugar de modificar saldos arbitrariamente, toda transferencia entre cuentas crea automáticamente dos registros atómicos (Transaction A: Gasto/Salida, Transaction B: Ingreso/Entrada). Si uno falla, ambos fallan (Rollback).
- **Relación Cuenta <-> Deuda (Tarjetas de Crédito):** 
  Una tarjeta de crédito no es solo una cuenta, es la combinación de una fuente de fondos (Cuenta) y un Pasivo (Deuda).
  - *Gasto con Tarjeta:* Disminuye Saldo Disponible (Cuenta) -> Lógica Mirror -> Aumenta Monto Restante (Deuda).
  - *Pago de Tarjeta:* Disminuye liquidez (Cuenta Origen) -> Lógica Mirror -> Aumenta Saldo Disponible (Tarjeta) y Disminuye Monto Restante (Deuda).

## 4. Política Anti-Hackeo Financiero
La validación "Anti-Hackeo" (evitar pagos mayores a la deuda restante, sobregiros no permitidos, etc.) ocurre fundamentalmente en la capa de **Repository** o mediante **RLS (Supabase)**.
- Está estrictamente prohibido permitir pagos de deuda por un monto mayor a la "Deuda Restante". El sistema (en el Repository o BD) rechazará/acortará cualquier monto excedente.
- Si el Working Balance de una cuenta no permite un gasto (ej. cuenta de efectivo a 0), puede permitirse el sobregiro solo si la configuración de la cuenta lo acepta de forma explícita; de lo contrario, debe bloquearse en el origen.
- **Rol de FinanceService:** El `FinanceService` **NO** es un middleware de escritura ni realiza validaciones de guardado. Es **estrictamente un orquestador de invalidación** para Riverpod.
- **Inmutabilidad del Estado Local:** Los repositorios y UI no calculan saldos arbitrarios; mutan la base de datos de manera atómica, y luego envían una señal a `FinanceService`, el cual es el ÚNICO capaz de despachar la invalidación y refresco de los reducers (Riverpod Providers).


## 5. Manejo de Fechas y Deuda Exigible (Tarjetas de Crédito)
El sistema debe diferenciar entre la deuda total y la deuda exigible (la que se debe pagar este mes).
- **Regla de Corte:** Cualquier transacción de gasto con tarjeta de crédito realizada *después* de la "Fecha de Corte" registrada en la cuenta, NO suma al pago mínimo ni a la deuda exigible del mes en curso; se difiere automáticamente al ciclo de facturación del mes siguiente.

## 6. Ajustes de Reconciliación (Reconciliation Adjustments)
Para alinear los saldos de la app con la realidad bancaria sin falsear los reportes, existe un tipo especial de transacción:
- **Transacción de Ajuste:** Es un movimiento de tipo 'ajuste_reconciliacion'. Su única función es igualar el "Cleared Balance" con el saldo real del banco. 
- **Regla de Neutralidad:** Estas transacciones modifican el saldo de la cuenta, pero son estrictamente invisibles para los reportes mensuales de "Ingresos" y "Gastos". No representan flujo de caja real, solo correcciones contables.

## 7. Protocolo de Desambiguación IA
Para asegurar el principio de "Seguridad por Diseño", la automatización mediante IA operará bajo estrictas reglas:
- **Aislamiento de Escritura:** La IA **NUNCA** guarda información ni escribe directamente en la base de datos (Supabase).
- **Proceso de Borrador:** El `IAService` procesará el lenguaje natural y devolverá exclusivamente un borrador en formato JSON estructurado. Este borrador debe ser validado y confirmado por el usuario en la UI antes de enviarse a través del `FinanceService` y los repositorios correspondientes.
- **Identificadores Únicos de Cuentas:** Para evitar el riesgo crítico de cruzar cuentas (ej. descontar fondos de la cuenta equivocada cuando hay múltiples tarjetas o bancos), la base de datos contará con los campos `last_four` (últimos 4 dígitos) y `tags` (etiquetas como nombres de bancos). Estos campos serán la clave primaria semántica de la IA para referenciar el `cuenta_origen_id` exacto.