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

