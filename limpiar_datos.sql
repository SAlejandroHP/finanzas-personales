-- Script para limpiar datos y comenzar desde 0 (conservando deudas y metas)
-- Instrucciones: Copia y pega este código en el "SQL Editor" de tu panel de Supabase y ejecútalo (botón RUN).

-- 1. Eliminar todas las transacciones (historial completo)
DELETE FROM transacciones;

-- 2. Eliminar todas las reglas de transacciones recurrentes
DELETE FROM reglas_recurrentes;

-- ====================================================================================
-- OPCIONES ADICIONALES (Descomenta quitando los "--" si deseas aplicarlas)
-- ====================================================================================

-- Opción A: Reiniciar los saldos de todas tus cuentas a 0 (pero conservando las cuentas)
UPDATE cuentas SET saldo_actual = 0;

-- Opción B: Si deseas eliminar TODAS tus cuentas (tendrás que volver a crearlas)
-- DELETE FROM cuentas;

-- Opción C: Si deseas borrar TODAS las categorías que has creado
-- DELETE FROM categorias;

-- Nota: Las tablas "deudas" y "metas" no se tocan, tal como lo solicitaste.
