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

