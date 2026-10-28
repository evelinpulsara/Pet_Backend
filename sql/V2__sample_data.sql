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

    ('22222222-2222-2222-2222-222222222222',
     'ana.torres@ejemplo.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMUJged0rty3OsOEqFkHbOjzBO',
     'Ana Torres Vega', '+57 300 987 6543', 'America/Bogota', TRUE),

    ('33333333-3333-3333-3333-333333333333',
     'luisa.fernandez@ejemplo.com',
     '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMUJged0rty3OsOEqFkHbOjzBO',
     'Luisa Fernández Mora', '+52 33 9876 5432', 'America/Mexico_City', FALSE);

-- ---- MASCOTAS ----
INSERT INTO pets (id, owner_id, name, species, breed, sex, birth_date,
                  color_description, microchip_number, is_neutered, status)
VALUES
    -- Carlos tiene 2 mascotas
    ('aaaa0001-0000-0000-0000-000000000001',
     '11111111-1111-1111-1111-111111111111',
     'Max', 'dog', 'Labrador Retriever', 'M', '2020-03-15',
     'Amarillo dorado, collar azul', 'MCH-2024-001', TRUE, 'home'),

    ('aaaa0002-0000-0000-0000-000000000002',
     '11111111-1111-1111-1111-111111111111',
     'Luna', 'cat', 'Siamés', 'F', '2021-07-20',
     'Crema con extremidades oscuras, ojos azules', NULL, TRUE, 'home'),

    -- Ana tiene 1 mascota
    ('aaaa0003-0000-0000-0000-000000000003',
     '22222222-2222-2222-2222-222222222222',
     'Coco', 'dog', 'French Bulldog', 'M', '2022-01-10',
     'Atigrado blanco y negro, collar rojo', 'MCH-2024-002', FALSE, 'lost'),

    -- Luisa tiene 1 mascota
    ('aaaa0004-0000-0000-0000-000000000004',
     '33333333-3333-3333-3333-333333333333',
     'Michi', 'cat', 'Mestizo', 'F', '2019-11-05',
     'Naranja con rayas, sin collar actualmente', NULL, TRUE, 'home');

-- ---- DISPOSITIVOS GPS ----
INSERT INTO tracker_devices (id, pet_id, device_uid, device_type, firmware_version,
                              battery_level, is_online, last_seen_at)
VALUES
    ('dddd0001-0000-0000-0000-000000000001',
     'aaaa0001-0000-0000-0000-000000000001',
     'PT-GPS-MX-000001', 'gps', '2.4.1', 87, TRUE, NOW() - INTERVAL '5 minutes'),

    ('dddd0002-0000-0000-0000-000000000002',
     'aaaa0003-0000-0000-0000-000000000003',
     'PT-GPS-CO-000003', 'gps', '2.4.0', 15, FALSE, NOW() - INTERVAL '3 hours');
    -- Luna y Michi no tienen dispositivo aún

-- ---- HISTORIAL DE UBICACIONES (datos ficticios, Ciudad de México) ----
-- Max — en su zona segura (casa de Carlos, Colonia Polanco)
INSERT INTO location_history (pet_id, device_id, recorded_at, latitude, longitude, accuracy_m, speed_kmh, battery_pct)
VALUES
    ('aaaa0001-0000-0000-0000-000000000001', 'dddd0001-0000-0000-0000-000000000001',
     NOW() - INTERVAL '60 minutes', 19.4326, -99.1332, 4.5, 0.0, 90),
    ('aaaa0001-0000-0000-0000-000000000001', 'dddd0001-0000-0000-0000-000000000001',
     NOW() - INTERVAL '30 minutes', 19.4328, -99.1335, 3.2, 2.1, 88),
    ('aaaa0001-0000-0000-0000-000000000001', 'dddd0001-0000-0000-0000-000000000001',
     NOW() - INTERVAL '5 minutes',  19.4327, -99.1333, 3.8, 0.0, 87);

-- Coco — última posición conocida antes de perderse (Bogotá, Chapinero)
INSERT INTO location_history (pet_id, device_id, recorded_at, latitude, longitude, accuracy_m, speed_kmh, battery_pct)
VALUES
    ('aaaa0003-0000-0000-0000-000000000003', 'dddd0002-0000-0000-0000-000000000002',
     NOW() - INTERVAL '4 hours',   4.6351, -74.0703, 8.0, 0.5, 30),
    ('aaaa0003-0000-0000-0000-000000000003', 'dddd0002-0000-0000-0000-000000000002',
     NOW() - INTERVAL '3 hours',   4.6380, -74.0750, 12.0, 4.2, 18),  -- Saliendo de zona
    ('aaaa0003-0000-0000-0000-000000000003', 'dddd0002-0000-0000-0000-000000000002',
     NOW() - INTERVAL '3 hours' + INTERVAL '5 minutes', 4.6395, -74.0780, 15.0, 1.0, 15); -- Última señal

