-- Migration: create_reglas_recurrentes_table

CREATE TABLE IF NOT EXISTS public.reglas_recurrentes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL, -- references auth.users(id) si tienes FK o public.users
    plantilla_transaccion JSONB NOT NULL,
    frecuencia VARCHAR(50) NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly'
    proxima_ocurrencia TIMESTAMP WITH TIME ZONE NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Habilitar RLS si aplica
ALTER TABLE public.reglas_recurrentes ENABLE ROW LEVEL SECURITY;

-- Crear políticas
CREATE POLICY "Users can view their own recurring rules" 
    ON public.reglas_recurrentes FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own recurring rules" 
    ON public.reglas_recurrentes FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own recurring rules" 
    ON public.reglas_recurrentes FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own recurring rules" 
    ON public.reglas_recurrentes FOR DELETE 
    USING (auth.uid() = user_id);
