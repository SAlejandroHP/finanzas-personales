-- Migration: create_cron_procesar_recurrentes

-- Asegurar que la extensión pg_cron existe (puede requerir habilitarse desde el Dashboard de Supabase)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Crear o reemplazar la función que procesa las reglas
CREATE OR REPLACE FUNCTION public.procesar_transacciones_recurrentes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    regla RECORD;
    nueva_fecha TIMESTAMP WITH TIME ZONE;
    nuevo_estado VARCHAR := 'completa';
BEGIN
    FOR regla IN 
        SELECT * FROM public.reglas_recurrentes 
        WHERE activa = true AND proxima_ocurrencia <= NOW()
    LOOP
        -- 1. Insertar la transacción generada a partir de la plantilla
        INSERT INTO public.transacciones (
            user_id,
            monto,
            tipo,
            categoria_id,
            cuenta_origen_id,
            cuenta_destino_id,
            descripcion,
            estado,
            fecha,
            is_recurring,
            deuda_id,
            meta_id
        ) VALUES (
            regla.user_id,
            (regla.plantilla_transaccion->>'monto')::numeric,
            regla.plantilla_transaccion->>'tipo',
            (regla.plantilla_transaccion->>'categoria_id')::uuid,
            (regla.plantilla_transaccion->>'cuenta_origen_id')::uuid,
            (regla.plantilla_transaccion->>'cuenta_destino_id')::uuid,
            regla.plantilla_transaccion->>'descripcion',
            nuevo_estado,
            regla.proxima_ocurrencia,
            false,
            (regla.plantilla_transaccion->>'deuda_id')::uuid,
            (regla.plantilla_transaccion->>'meta_id')::uuid
        );

        -- 2. Calcular la próxima ocurrencia basada en la frecuencia
        IF regla.frecuencia = 'daily' THEN
            nueva_fecha := regla.proxima_ocurrencia + INTERVAL '1 day';
        ELSIF regla.frecuencia = 'weekly' THEN
            nueva_fecha := regla.proxima_ocurrencia + INTERVAL '1 week';
        ELSIF regla.frecuencia = 'monthly' THEN
            nueva_fecha := regla.proxima_ocurrencia + INTERVAL '1 month';
        ELSIF regla.frecuencia = 'yearly' THEN
            nueva_fecha := regla.proxima_ocurrencia + INTERVAL '1 year';
        ELSE
            nueva_fecha := regla.proxima_ocurrencia + INTERVAL '1 month'; -- Fallback
        END IF;

        -- 3. Actualizar la regla con la nueva fecha de ocurrencia
        UPDATE public.reglas_recurrentes
        SET proxima_ocurrencia = nueva_fecha,
            updated_at = NOW()
        WHERE id = regla.id;

        -- 4. Actualizar saldos de cuentas
        IF nuevo_estado = 'completa' THEN
            -- Cuenta origen
            IF (regla.plantilla_transaccion->>'tipo') IN ('gasto', 'transferencia', 'pago_deuda', 'meta_aporte') THEN
                UPDATE public.cuentas 
                SET saldo_actual = saldo_actual - (regla.plantilla_transaccion->>'monto')::numeric
                WHERE id = (regla.plantilla_transaccion->>'cuenta_origen_id')::uuid;
            ELSIF (regla.plantilla_transaccion->>'tipo') = 'ingreso' THEN
                UPDATE public.cuentas 
                SET saldo_actual = saldo_actual + (regla.plantilla_transaccion->>'monto')::numeric
                WHERE id = (regla.plantilla_transaccion->>'cuenta_origen_id')::uuid;
            END IF;

            -- Cuenta destino
            IF (regla.plantilla_transaccion->>'cuenta_destino_id') IS NOT NULL THEN
                UPDATE public.cuentas 
                SET saldo_actual = saldo_actual + (regla.plantilla_transaccion->>'monto')::numeric
                WHERE id = (regla.plantilla_transaccion->>'cuenta_destino_id')::uuid;
            END IF;
            
            -- Actualizar metas si es aporte
            IF (regla.plantilla_transaccion->>'tipo') = 'meta_aporte' AND (regla.plantilla_transaccion->>'meta_id') IS NOT NULL THEN
                UPDATE public.metas
                SET current_amount = current_amount + (regla.plantilla_transaccion->>'monto')::numeric
                WHERE id = (regla.plantilla_transaccion->>'meta_id')::uuid;
            END IF;
            
            -- Actualizar deuda si es pago de deuda
            IF (regla.plantilla_transaccion->>'tipo') = 'pago_deuda' AND (regla.plantilla_transaccion->>'deuda_id') IS NOT NULL THEN
                UPDATE public.deudas
                SET monto_restante = GREATEST(0, monto_restante - (regla.plantilla_transaccion->>'monto')::numeric),
                    estado = CASE WHEN monto_restante - (regla.plantilla_transaccion->>'monto')::numeric <= 0 THEN 'pagada' ELSE 'activa' END
                WHERE id = (regla.plantilla_transaccion->>'deuda_id')::uuid;
            END IF;
        END IF;

    END LOOP;
END;
$$;

-- Desprogramar ejecución previa si existe (ignora errores si no existe)
DO $$
BEGIN
    PERFORM cron.unschedule('procesar_recurrentes_diario');
EXCEPTION WHEN OTHERS THEN
    -- Ignorar error
END $$;

-- Programar la ejecución diaria a la 01:00 AM
SELECT cron.schedule('procesar_recurrentes_diario', '0 1 * * *', 'SELECT public.procesar_transacciones_recurrentes();');
