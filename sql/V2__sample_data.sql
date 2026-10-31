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

-- ---- ZONAS SEGURAS ----
INSERT INTO safe_zones (id, pet_id, name, zone_type, center_lat, center_lon, radius_m)
VALUES
    -- Casa de Carlos (Max)
    ('zzzz0001-0000-0000-0000-000000000001',
     'aaaa0001-0000-0000-0000-000000000001',
     'Casa', 'home', 19.4326, -99.1332, 150.0),
    -- Parque donde llevan a Max
    ('zzzz0002-0000-0000-0000-000000000002',
     'aaaa0001-0000-0000-0000-000000000001',
     'Parque Lincoln', 'park', 19.4361, -99.1969, 300.0),
    -- Casa de Ana (Coco) — ahora extraviado
    ('zzzz0003-0000-0000-0000-000000000003',
     'aaaa0003-0000-0000-0000-000000000003',
     'Apartamento', 'home', 4.6351, -74.0703, 100.0);

-- ---- ALERTAS ----
INSERT INTO alerts (pet_id, zone_id, alert_type, severity, message, latitude, longitude)
VALUES
    -- Coco salió de zona
    ('aaaa0003-0000-0000-0000-000000000003',
     'zzzz0003-0000-0000-0000-000000000003',
     'out_of_zone', 'high',
     'Coco salió de la zona segura "Apartamento". Distancia estimada: 300 m.',
     4.6380, -74.0750),
    -- Dispositivo de Coco sin señal
    ('aaaa0003-0000-0000-0000-000000000003',
     NULL,
     'device_offline', 'critical',
     'El dispositivo de Coco (PT-GPS-CO-000003) no envía señal desde hace 3 horas. Batería: 15%.',
     NULL, NULL),
    -- Batería baja de Max (aviso preventivo)
    ('aaaa0001-0000-0000-0000-000000000001',
     NULL,
     'low_battery', 'low',
     'Batería del dispositivo de Max al 15%. Se recomienda recargar pronto.',
     NULL, NULL);

-- Marcar la alerta de batería de Max como resuelta (Carlos recargó el dispositivo)
UPDATE alerts
SET is_resolved = TRUE, resolved_at = NOW() - INTERVAL '10 minutes',
    resolved_by_id = '11111111-1111-1111-1111-111111111111'
WHERE pet_id = 'aaaa0001-0000-0000-0000-000000000001'
  AND alert_type = 'low_battery';

-- ---- FICHAS MÉDICAS ----
INSERT INTO medical_records (pet_id, blood_type, weight_kg, known_allergies,
                              chronic_conditions, vet_name, vet_phone)
VALUES
    ('aaaa0001-0000-0000-0000-000000000001',
     'DEA 1.1+', 32.5, 'Ninguna conocida', NULL,
     'Clínica Veterinaria Polanco', '+52 55 5555 1234'),

    ('aaaa0002-0000-0000-0000-000000000002',
     NULL, 3.8, 'Camarones (mariscos)', NULL,
     'Clínica Veterinaria Polanco', '+52 55 5555 1234'),

    ('aaaa0003-0000-0000-0000-000000000003',
     NULL, 12.0, NULL, 'Alergia respiratoria estacional',
     'Vetlandia Chapinero', '+57 1 234 5678');

-- ---- VACUNAS ----
INSERT INTO vaccinations (pet_id, vaccine_name, administered_at, next_due_date, administered_by)
VALUES
    ('aaaa0001-0000-0000-0000-000000000001',
     'Rabia', '2024-03-01', '2025-03-01', 'Dra. Ramírez'),
    ('aaaa0001-0000-0000-0000-000000000001',
     'Polivalente (DHPP)', '2024-03-01', '2025-03-01', 'Dra. Ramírez'),
    ('aaaa0003-0000-0000-0000-000000000003',
     'Rabia', '2023-11-15', '2024-11-15', 'Dr. Herrera'),
    ('aaaa0002-0000-0000-0000-000000000002',
     'Triple felina (HCPCh)', '2024-06-10', '2025-06-10', 'Dra. Ramírez');

-- ---- MEDICAMENTOS ----
INSERT INTO medications (pet_id, name, dosage, start_date, end_date, prescribed_by, is_active)
VALUES
    ('aaaa0001-0000-0000-0000-000000000001',
     'Simparica (antipulgas)', '1 tableta mensual', '2024-01-01', NULL,
     'Dra. Ramírez', TRUE),
    ('aaaa0003-0000-0000-0000-000000000003',
     'Cetirizina (antialérgico)', '5 mg cada 24 horas', '2024-09-01', '2024-10-01',
     'Dr. Herrera', FALSE);

-- ---- CONTACTOS DE EMERGENCIA ----
INSERT INTO emergency_contacts (pet_id, full_name, relationship, phone, email, is_primary)
VALUES
    -- Contactos para Max
    ('aaaa0001-0000-0000-0000-000000000001',
     'María Mendoza', 'Familiar (hermana)', '+52 55 8888 9999', 'maria.mendoza@ejemplo.com', TRUE),
    ('aaaa0001-0000-0000-0000-000000000001',
     'Vecino Juan', 'Vecino de confianza', '+52 55 7777 6666', NULL, FALSE),
    -- Contacto para Coco (extraviado)
    ('aaaa0003-0000-0000-0000-000000000003',
     'Pedro Torres', 'Familiar (hermano)', '+57 310 111 2222', 'pedro.torres@ejemplo.com', TRUE);

-- ---- REPORTE DE EXTRAVÍO (Coco) ----
INSERT INTO lost_pet_reports (pet_id, last_seen_at, last_seen_lat, last_seen_lon,
                               last_seen_address, public_contact, description_for_finder)
VALUES
    ('aaaa0003-0000-0000-0000-000000000003',
     NOW() - INTERVAL '3 hours',
     4.6395, -74.0780,
     'Carrera 7 con Calle 63, Chapinero, Bogotá',
     '+57 300 987 6543 (Ana)',
     'Bulldog francés, atigrado blanco y negro, collar rojo. Responde al nombre Coco. Es amigable. Por favor llamar a Ana.');

-- ---- PATRONES DE IA (resultado ficticio de análisis previo de Max) ----
INSERT INTO ai_movement_patterns (pet_id, pattern_type, description, confidence,
                                   data_from, data_to, model_version)
VALUES
    ('aaaa0001-0000-0000-0000-000000000001',
     'daily_routine',
     'Max permanece en casa entre las 10 PM y las 7 AM con 94% de consistencia.',
     0.940,
     '2024-08-01 00:00:00+00', '2024-10-01 00:00:00+00',
     'movement-v0.1-alpha'),
    ('aaaa0001-0000-0000-0000-000000000001',
     'frequent_zone',
     'Visita el Parque Lincoln entre 3 y 5 veces por semana, generalmente entre 7 AM y 9 AM.',
     0.870,
     '2024-08-01 00:00:00+00', '2024-10-01 00:00:00+00',
     'movement-v0.1-alpha');

