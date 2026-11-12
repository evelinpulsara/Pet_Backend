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

-- Historial de ubicaciones (lo envía el collar)
CREATE TABLE IF NOT EXISTS pettracker.location_history (
    id              BIGSERIAL   PRIMARY KEY,
    pet_id          UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    device_id       UUID        REFERENCES pettracker.tracker_devices(id) ON DELETE SET NULL,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    latitude        NUMERIC(10, 7) NOT NULL,
    longitude       NUMERIC(10, 7) NOT NULL,
    accuracy_m      NUMERIC(6, 2),
    speed_kmh       NUMERIC(6, 2),
    battery_pct     SMALLINT,
    CONSTRAINT loc_latitude_range  CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT loc_longitude_range CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT loc_battery_range   CHECK (battery_pct IS NULL OR battery_pct BETWEEN 0 AND 100)
);

-- Zonas seguras (varias por mascota; is_home marca "Casa")
CREATE TABLE IF NOT EXISTS pettracker.safe_zones (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,
    center_lat      NUMERIC(10, 7) NOT NULL,
    center_lon      NUMERIC(10, 7) NOT NULL,
    radius_m        NUMERIC(8, 2) NOT NULL,
    is_home         BOOLEAN     NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT zone_lat_range    CHECK (center_lat BETWEEN -90  AND 90),
    CONSTRAINT zone_lon_range    CHECK (center_lon BETWEEN -180 AND 180),
    CONSTRAINT zone_radius_range CHECK (radius_m BETWEEN 10 AND 50000)
);

-- Alertas (mismos tipos que la app)
CREATE TABLE IF NOT EXISTS pettracker.alerts (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    alert_type      VARCHAR(40) NOT NULL,
    params          JSONB       NOT NULL DEFAULT '{}'::jsonb,  -- Datos para armar el texto en cada idioma
    message         TEXT        NOT NULL,
    latitude        NUMERIC(10, 7),
    longitude       NUMERIC(10, 7),
    is_resolved     BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT alert_type_values CHECK (alert_type IN (
        'leftSafeZone', 'enteredSafeZone', 'lowBattery', 'gpsLost',
        'trackerDisconnected', 'anomaly', 'healthReminder'))
);

-- Contactos de emergencia
CREATE TABLE IF NOT EXISTS pettracker.emergency_contacts (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    full_name       VARCHAR(150) NOT NULL,
    relationship    VARCHAR(80),
    phone           VARCHAR(25) NOT NULL,
    is_primary      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Carnet de salud: vacunas, desparasitación, citas y medicamentos
CREATE TABLE IF NOT EXISTS pettracker.health_records (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    record_type     VARCHAR(20) NOT NULL,
    title           VARCHAR(150) NOT NULL,
    record_date     DATE        NOT NULL,
    next_due_date   DATE,                    -- Para los recordatorios
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT health_type_values CHECK (record_type IN ('vaccine', 'deworming', 'vet', 'medication'))
);

-- Paseos grabados
CREATE TABLE IF NOT EXISTS pettracker.walks (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    started_at      TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ,
    distance_m      NUMERIC(10, 1) NOT NULL DEFAULT 0,
    route           JSONB       NOT NULL DEFAULT '[]'::jsonb,   -- [{lat, lng, acc, t}, ...]
    CONSTRAINT walk_dates CHECK (ended_at IS NULL OR ended_at >= started_at)
);

-- Actividad por día
CREATE TABLE IF NOT EXISTS pettracker.daily_activity (
    pet_id          UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    day             DATE        NOT NULL,
    distance_m      NUMERIC(10, 1) NOT NULL DEFAULT 0,
    active_seconds  INTEGER     NOT NULL DEFAULT 0,
    PRIMARY KEY (pet_id, day)
);

-- Reportes de mascota perdida (modo búsqueda + cartel "Se busca")
CREATE TABLE IF NOT EXISTS pettracker.lost_pet_reports (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id              UUID        NOT NULL REFERENCES pettracker.pets(id) ON DELETE CASCADE,
    is_manual           BOOLEAN     NOT NULL DEFAULT FALSE,   -- TRUE = el dueño activó "se perdió"
    reported_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_lat       NUMERIC(10, 7),
    last_seen_lon       NUMERIC(10, 7),
    last_seen_zone      VARCHAR(100),
    poster_headline     TEXT,
    poster_description  TEXT,
    is_found            BOOLEAN     NOT NULL DEFAULT FALSE,
    found_at            TIMESTAMPTZ,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT lost_found_consistency CHECK (
        (is_found = FALSE AND found_at IS NULL) OR (is_found = TRUE AND found_at IS NOT NULL))
);

-- ====================================================================
--  ÍNDICES
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_pets_owner            ON pettracker.pets(owner_id);
CREATE INDEX IF NOT EXISTS idx_devices_pet           ON pettracker.tracker_devices(pet_id);
CREATE INDEX IF NOT EXISTS idx_location_pet_time     ON pettracker.location_history(pet_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_zones_pet             ON pettracker.safe_zones(pet_id);
CREATE INDEX IF NOT EXISTS idx_alerts_pet_time       ON pettracker.alerts(pet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_contacts_pet          ON pettracker.emergency_contacts(pet_id);
CREATE INDEX IF NOT EXISTS idx_health_pet_due        ON pettracker.health_records(pet_id, next_due_date);
CREATE INDEX IF NOT EXISTS idx_walks_pet_time        ON pettracker.walks(pet_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_lost_reports_pet      ON pettracker.lost_pet_reports(pet_id, reported_at DESC);

-- ====================================================================
--  FUNCIONES Y TRIGGERS
-- ====================================================================

-- updated_at automático
CREATE OR REPLACE FUNCTION pettracker.fn_update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

DO $$
DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['profiles', 'pets', 'safe_zones', 'health_records', 'lost_pet_reports'] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%1$s_updated_at ON pettracker.%1$I', t);
        EXECUTE format('CREATE TRIGGER trg_%1$s_updated_at BEFORE UPDATE ON pettracker.%1$I
                        FOR EACH ROW EXECUTE FUNCTION pettracker.fn_update_updated_at()', t);
    END LOOP;
END;
$$;

-- ¿La mascota es del usuario que está conectado? (lo usan las políticas RLS)
CREATE OR REPLACE FUNCTION pettracker.owns_pet(p_pet_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT EXISTS (SELECT 1 FROM pettracker.pets p WHERE p.id = p_pet_id AND p.owner_id = auth.uid());
$$;

-- Crea el perfil cuando alguien se registra DESDE PetTracker.
-- Solo actúa si al registrarse se envió metadata app = 'pettracker'
-- (acordado con las otras apps del proyecto: no tocamos sus usuarios).
CREATE OR REPLACE FUNCTION pettracker.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF NEW.raw_user_meta_data->>'app' = 'pettracker' THEN
        INSERT INTO pettracker.profiles (id, full_name)
        VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)))
        ON CONFLICT (id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$;

