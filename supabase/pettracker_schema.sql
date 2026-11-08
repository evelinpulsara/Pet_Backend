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

