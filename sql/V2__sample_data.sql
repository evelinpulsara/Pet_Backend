-- ====================================================================
--  PROYECTO: Sistema de Rastreo de Mascotas con IA
--  Script: V2__sample_data.sql  (compatible con Flyway)
--  Datos completamente ficticios — solo para pruebas de desarrollo.
--
--  CONTRASEÑAS: Todas usan el hash BCrypt de 'PetTracker2024!'
--  (factor de costo 12). En producción, el hash lo genera Spring Security.
-- ====================================================================

-- ---- USUARIOS FICTICIOS ----
INSERT INTO users (id, email, password_hash, full_name, phone, timezone, is_verified)
VALUES
    ('11111111-1111-1111-1111-111111111111',
     'carlos.mendez@ejemplo.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMUJged0rty3OsOEqFkHbOjzBO',
     'Carlos Mendoza Ríos', '+52 55 1234 5678', 'America/Mexico_City', TRUE),

