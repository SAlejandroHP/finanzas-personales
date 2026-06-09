-- Agrega las columnas fecha_corte y fecha_limite_pago a la tabla cuentas
-- Ambas son de tipo INTEGER, representando el día del mes (1-31).

ALTER TABLE cuentas 
ADD COLUMN IF NOT EXISTS fecha_corte INTEGER DEFAULT NULL,
ADD COLUMN IF NOT EXISTS fecha_limite_pago INTEGER DEFAULT NULL;
