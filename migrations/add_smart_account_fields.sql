-- Migración para añadir soporte IA y Smart Onboarding a la tabla de cuentas
-- Fase 8.2: Actualización de base de datos

ALTER TABLE IF EXISTS public.cuentas 
ADD COLUMN IF NOT EXISTS last_four VARCHAR(4),
ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS is_virtual BOOLEAN DEFAULT false;

-- Comentarios explicativos para los nuevos campos
COMMENT ON COLUMN public.cuentas.last_four IS 'Últimos 4 dígitos de la cuenta para identificación rápida (especialmente útil para IA y UX)';
COMMENT ON COLUMN public.cuentas.tags IS 'Etiquetas de búsqueda como el nombre de la bóveda, banco o apodos (ej. BBVA, Mi alcancía) para la IA';
COMMENT ON COLUMN public.cuentas.is_virtual IS 'Indica si es una cuenta creada de forma virtual sin vinculación física estricta, o como contenedor puramente organizativo';
