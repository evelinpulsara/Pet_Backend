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

-- Mascotas
CREATE TABLE IF NOT EXISTS pettracker.pets (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id        UUID        NOT NULL DEFAULT auth.uid() REFERENCES pettracker.profiles(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,
    species         VARCHAR(50)  NOT NULL,          -- Texto libre: 'Perro', 'Gato', 'Otro'...
    breed           VARCHAR(100),
    age_years       SMALLINT,
    weight_kg       NUMERIC(5, 2),
    color_argb      BIGINT,                          -- Color de la mascota en la app (0xAARRGGBB)
    photo_url       VARCHAR(500),                    -- Foto en Supabase Storage (no en la BD)
    daily_goal_m    NUMERIC(8, 1) NOT NULL DEFAULT 3000,
    status          VARCHAR(20) NOT NULL DEFAULT 'home',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pet_name_not_empty CHECK (char_length(trim(name)) > 0),
    CONSTRAINT pet_age_range      CHECK (age_years IS NULL OR age_years BETWEEN 0 AND 60),
    CONSTRAINT pet_weight_pos     CHECK (weight_kg IS NULL OR weight_kg > 0),
    CONSTRAINT pet_status_values  CHECK (status IN ('home', 'away', 'lost', 'found', 'inactive'))
);

-- Collares GPS (uno activo por mascota)
CREATE TABLE IF NOT EXISTS pettracker.tracker_devices (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    device_uid      VARCHAR(100) NOT NULL UNIQUE,   -- Código del collar, ej. 'TRK-1001'
    device_key_hash VARCHAR(64),                    -- SHA-256 de la clave secreta del collar
    battery_level   SMALLINT,
    is_online       BOOLEAN     NOT NULL DEFAULT FALSE,
    power_save      BOOLEAN     NOT NULL DEFAULT FALSE,
    signal          SMALLINT,                       -- 0..4
    last_seen_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT device_battery_range CHECK (battery_level IS NULL OR battery_level BETWEEN 0 AND 100),
    CONSTRAINT device_signal_range  CHECK (signal IS NULL OR signal BETWEEN 0 AND 4)
);
COMMENT ON COLUMN pettracker.tracker_devices.device_key_hash IS
  'El collar se identifica con device_uid + una clave secreta. Solo se guarda el hash.';

