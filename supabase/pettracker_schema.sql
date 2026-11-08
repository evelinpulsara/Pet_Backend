-- ====================================================================
--  PetTracker — Esquema para SUPABASE (proyecto compartido)
--  Base de datos: PostgreSQL 15+ (Supabase)
--
--  Este proyecto de Supabase lo comparten varias apps. Cada una vive en
--  su propio esquema y NO toca el de las demás:
--     pettracker  -> esta app (rastreo GPS de mascotas)
--     restotime   -> app del restaurante (no tocar)
--     public      -> otra app (Spring Boot) (no tocar)
--
--  CÓMO USARLO:
--   1. Supabase -> SQL Editor -> pega TODO este archivo -> Run.
--      Se puede volver a ejecutar sin perder datos (no borra tablas).
--   2. Settings -> API -> Exposed schemas: agrega `pettracker`.
--   3. En la app se usa SOLO la clave pública (anon/publishable).
--      Nunca pongas la service_role key en la app.
--
--  Seguridad: Row Level Security (RLS) en todas las tablas. Cada usuario
--  solo ve y modifica sus propias mascotas y lo que cuelga de ellas.
-- ====================================================================

CREATE SCHEMA IF NOT EXISTS pettracker;

-- pgcrypto ya viene en Supabase (esquema `extensions`). Solo por si acaso:
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- ====================================================================
--  TABLAS
-- ====================================================================

-- Perfil del dueño (1:1 con auth.users de Supabase).
CREATE TABLE IF NOT EXISTS pettracker.profiles (
    id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name   VARCHAR(150),
    phone       VARCHAR(25),                      -- Aparece en el cartel de "Se busca"
    language    VARCHAR(5)  NOT NULL DEFAULT 'es',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT profile_language CHECK (language IN ('es', 'en'))
);
COMMENT ON TABLE pettracker.profiles IS 'Dueños de mascotas de PetTracker (perfil ligado a auth.users).';

