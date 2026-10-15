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
