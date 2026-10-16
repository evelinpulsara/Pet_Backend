-- ====================================================================
--  PROYECTO: Sistema de Rastreo de Mascotas con IA
--  Base de Datos: PostgreSQL 15+
--  Script:  V1__schema.sql  (compatible con Flyway)
--  Autor:   Proyecto Académico
--
--  INSTRUCCIONES DE REEMPLAZO SEGURO (si ya tenías un esquema anterior):
--  Ejecuta esto primero EN TU BASE DE DATOS DE DESARROLLO (¡no en producción!):
--      DROP SCHEMA public CASCADE;
--      CREATE SCHEMA public;
--  Luego ejecuta este archivo completo.
-- ====================================================================

-- Extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "pgcrypto";      -- Para gen_random_uuid() y funciones de hash
CREATE EXTENSION IF NOT EXISTS "postgis";       -- Para tipos geográficos (GEOGRAPHY/GEOMETRY)
-- NOTA: PostGIS puede no estar disponible en todos los planes gratuitos.
-- Si no está disponible, usa NUMERIC(10,7) para lat/lon (ver comentario en location_history).

-- ====================================================================
--  TABLA: users
--  Propietarios de mascotas. Autenticación con hash BCrypt.
-- ====================================================================
CREATE TABLE users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255)    NOT NULL,   -- BCrypt hash (nunca texto plano)
    full_name       VARCHAR(150)    NOT NULL,
    phone           VARCHAR(25),                -- Opcional, para alertas SMS
    avatar_url      VARCHAR(500),               -- URL de foto de perfil
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_verified     BOOLEAN         NOT NULL DEFAULT FALSE,  -- Verificación de email
    timezone        VARCHAR(60)     NOT NULL DEFAULT 'America/Mexico_City',
    language        VARCHAR(10)     NOT NULL DEFAULT 'es',
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- Preferencias de notificación
    notify_email    BOOLEAN         NOT NULL DEFAULT TRUE,
    notify_push     BOOLEAN         NOT NULL DEFAULT TRUE,
    notify_sms      BOOLEAN         NOT NULL DEFAULT FALSE,

    CONSTRAINT users_email_format CHECK (
        email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'
    )
);

COMMENT ON TABLE  users               IS 'Usuarios registrados. Propietarios de mascotas.';
COMMENT ON COLUMN users.password_hash IS 'Hash BCrypt (costo ≥ 12). NUNCA almacenar contraseña en texto plano.';
COMMENT ON COLUMN users.is_verified   IS 'TRUE cuando el usuario confirma su correo electrónico.';

-- ====================================================================
--  TABLA: refresh_tokens
--  Tokens de renovación JWT para sesiones persistentes.
-- ====================================================================
CREATE TABLE refresh_tokens (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  VARCHAR(255) NOT NULL UNIQUE,  -- Hash SHA-256 del token real
    device_info VARCHAR(300),                  -- Navegador / SO del dispositivo
    ip_address  INET,
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked     BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  refresh_tokens            IS 'Tokens de refresco JWT. El token real nunca se almacena, solo su hash.';
COMMENT ON COLUMN refresh_tokens.token_hash IS 'SHA-256 del refresh token. El token en texto claro se envía solo al cliente.';

-- ====================================================================
--  TABLA: pets
--  Información principal de cada mascota.
-- ====================================================================
CREATE TABLE pets (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id            UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name                VARCHAR(100) NOT NULL,
    species             VARCHAR(50)  NOT NULL,   -- 'dog', 'cat', 'bird', 'rabbit', 'other'
    breed               VARCHAR(100),
    sex                 CHAR(1)     NOT NULL,    -- 'M' (macho), 'F' (hembra), 'U' (desconocido)
    birth_date          DATE,
    color_description   VARCHAR(200),            -- "negro con manchas blancas en el pecho"
    photo_url           VARCHAR(500),            -- URL en almacenamiento seguro (S3, etc.)
    microchip_number    VARCHAR(50),             -- Número de microchip (si tiene)
    is_neutered         BOOLEAN,
    status              VARCHAR(20) NOT NULL DEFAULT 'home',  -- 'home', 'away', 'lost', 'inactive'
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT pet_species_values CHECK (
        species IN ('dog', 'cat', 'bird', 'rabbit', 'reptile', 'fish', 'other')
    ),
    CONSTRAINT pet_sex_values CHECK (sex IN ('M', 'F', 'U')),
    CONSTRAINT pet_status_values CHECK (
        status IN ('home', 'away', 'lost', 'found', 'inactive')
    ),
    CONSTRAINT pet_name_not_empty CHECK (char_length(trim(name)) > 0)
);

COMMENT ON TABLE  pets         IS 'Registro de mascotas. Cada mascota pertenece a un usuario (owner_id).';
COMMENT ON COLUMN pets.status  IS 'home=en casa, away=fuera de zona, lost=extraviada, found=recuperada, inactive=dispositivo apagado.';
COMMENT ON COLUMN pets.photo_url IS 'URL pública o firmada hacia el almacenamiento de imágenes. No guardar la imagen en la BD.';

-- ====================================================================
--  TABLA: tracker_devices
--  Dispositivos GPS/BLE asociados a una mascota.
-- ====================================================================
CREATE TABLE tracker_devices (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    device_uid      VARCHAR(100) NOT NULL UNIQUE,  -- Identificador único del hardware
    device_type     VARCHAR(50) NOT NULL DEFAULT 'gps',  -- 'gps', 'ble', 'lora', 'wifi'
    firmware_version VARCHAR(20),
    battery_level   SMALLINT,                       -- 0-100 (%)
    is_online       BOOLEAN     NOT NULL DEFAULT FALSE,
    last_seen_at    TIMESTAMPTZ,                    -- Última vez que el dispositivo envió señal
    activated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deactivated_at  TIMESTAMPTZ,

    CONSTRAINT device_battery_range CHECK (battery_level IS NULL OR battery_level BETWEEN 0 AND 100),
    CONSTRAINT device_type_values CHECK (
        device_type IN ('gps', 'ble', 'lora', 'wifi', 'other')
    )
);

COMMENT ON TABLE  tracker_devices          IS 'Dispositivos de rastreo vinculados a una mascota. Un dispositivo activo por mascota a la vez.';
COMMENT ON COLUMN tracker_devices.device_uid IS 'ID de hardware único. Lo proporciona el fabricante del dispositivo.';
COMMENT ON COLUMN tracker_devices.is_online  IS 'Actualizado por el servidor cuando recibe señal del dispositivo.';

-- ====================================================================
--  TABLA: location_history
--  Historial de coordenadas GPS de cada mascota.
--  NOTA ACADÉMICA: Los datos reales requieren un dispositivo GPS físico
--  y un servidor MQTT/WebSocket para recibir las coordenadas.
--  Esta tabla almacena los datos UNA VEZ que ya fueron recibidos.
-- ====================================================================
CREATE TABLE location_history (
    id              BIGSERIAL   PRIMARY KEY,           -- BIGSERIAL: puede haber millones de registros
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    device_id       UUID        REFERENCES tracker_devices(id) ON DELETE SET NULL,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Coordenadas — PostGIS (si está disponible):
    -- location     GEOGRAPHY(POINT, 4326),
    -- Sin PostGIS usa estas dos columnas:
    latitude        NUMERIC(10, 7) NOT NULL,    -- -90 a +90
    longitude       NUMERIC(10, 7) NOT NULL,    -- -180 a +180
    altitude_m      NUMERIC(7, 2),              -- Altitud en metros (opcional)
    accuracy_m      NUMERIC(6, 2),              -- Precisión del GPS en metros
    speed_kmh       NUMERIC(6, 2),              -- Velocidad calculada (km/h)
    heading_deg     NUMERIC(5, 2),              -- Dirección del movimiento (0-360°)
    battery_pct     SMALLINT,                   -- Nivel de batería en el momento del registro

