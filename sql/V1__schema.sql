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

    CONSTRAINT loc_latitude_range  CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT loc_longitude_range CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT loc_speed_positive  CHECK (speed_kmh IS NULL OR speed_kmh >= 0),
    CONSTRAINT loc_heading_range   CHECK (heading_deg IS NULL OR heading_deg BETWEEN 0 AND 360),
    CONSTRAINT loc_battery_range   CHECK (battery_pct IS NULL OR battery_pct BETWEEN 0 AND 100)
);

COMMENT ON TABLE  location_history IS 'Serie temporal de posiciones GPS. Puede crecer a millones de filas; el índice de fecha es crítico.';
COMMENT ON COLUMN location_history.accuracy_m IS 'Margen de error del GPS en metros. Cuanto menor, más preciso.';
COMMENT ON COLUMN location_history.speed_kmh  IS 'Calculada por el dispositivo o el servidor. No disponible en todos los modelos.';

-- ====================================================================
--  TABLA: safe_zones
--  Zonas seguras configuradas por el usuario (hogar, parque, etc.)
-- ====================================================================
CREATE TABLE safe_zones (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,          -- "Casa", "Parque Central", "Trabajo"
    zone_type       VARCHAR(30) NOT NULL DEFAULT 'home',  -- 'home', 'park', 'vet', 'custom'
    center_lat      NUMERIC(10, 7) NOT NULL,
    center_lon      NUMERIC(10, 7) NOT NULL,
    radius_m        NUMERIC(8, 2) NOT NULL,         -- Radio de la zona segura en metros
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    schedule_start  TIME,                            -- Hora inicio del horario activo (NULL = siempre)
    schedule_end    TIME,                            -- Hora fin del horario activo
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT zone_lat_range    CHECK (center_lat BETWEEN -90  AND 90),
    CONSTRAINT zone_lon_range    CHECK (center_lon BETWEEN -180 AND 180),
    CONSTRAINT zone_radius_range CHECK (radius_m   BETWEEN 10   AND 50000),
    CONSTRAINT zone_type_values  CHECK (
        zone_type IN ('home', 'park', 'vet', 'school', 'custom')
    ),
    CONSTRAINT zone_schedule_order CHECK (
        schedule_start IS NULL OR schedule_end IS NULL OR schedule_end > schedule_start
    )
);

COMMENT ON TABLE  safe_zones          IS 'Zonas geográficas seguras definidas por el usuario. Se usa para generar alertas de salida.';
COMMENT ON COLUMN safe_zones.radius_m IS 'Radio en metros desde el centro de la zona. Mínimo 10m, máximo 50km.';

-- ====================================================================
--  TABLA: alerts
--  Alertas generadas cuando una mascota sale de una zona segura,
--  el dispositivo pierde señal, o la IA detecta comportamiento inusual.
-- ====================================================================
CREATE TABLE alerts (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    zone_id         UUID        REFERENCES safe_zones(id) ON DELETE SET NULL,
    alert_type      VARCHAR(50) NOT NULL,
    -- 'out_of_zone'    : mascota salió de la zona segura
    -- 'device_offline' : dispositivo perdió conexión
    -- 'low_battery'    : batería baja (<20%)
    -- 'unusual_activity': IA detectó comportamiento inusual
    -- 'pet_lost'       : marcada como extraviada manualmente
    severity        VARCHAR(10) NOT NULL DEFAULT 'medium',  -- 'low', 'medium', 'high', 'critical'
    message         TEXT        NOT NULL,
    latitude        NUMERIC(10, 7),    -- Posición cuando se generó la alerta
    longitude       NUMERIC(10, 7),
    is_resolved     BOOLEAN     NOT NULL DEFAULT FALSE,
    resolved_at     TIMESTAMPTZ,
    resolved_by_id  UUID        REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT alert_type_values CHECK (
        alert_type IN ('out_of_zone','device_offline','low_battery','unusual_activity','pet_lost','other')
    ),
    CONSTRAINT alert_severity_values CHECK (
        severity IN ('low','medium','high','critical')
    ),
    CONSTRAINT alert_resolved_consistency CHECK (
        (is_resolved = FALSE AND resolved_at IS NULL) OR
        (is_resolved = TRUE  AND resolved_at IS NOT NULL)
    )
);

COMMENT ON TABLE alerts IS 'Alertas del sistema. Generadas por reglas geográficas, estado del dispositivo o módulos de IA.';

-- ====================================================================
--  TABLA: medical_records
--  Ficha médica de la mascota (1:1 con pets, se crea junto a la mascota).
-- ====================================================================
CREATE TABLE medical_records (
    id              UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID    NOT NULL UNIQUE REFERENCES pets(id) ON DELETE CASCADE,
    blood_type      VARCHAR(10),
    weight_kg       NUMERIC(5, 2),
    known_allergies TEXT,               -- Texto libre: "Polen, penicilina"
    chronic_conditions TEXT,            -- Texto libre: "Diabetes tipo 1, artritis"
    dietary_restrictions TEXT,
    vet_name        VARCHAR(150),       -- Veterinario/clínica habitual
    vet_phone       VARCHAR(25),
    vet_address     TEXT,
    insurance_policy VARCHAR(100),      -- Número de póliza (si aplica)
    notes           TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT medical_weight_positive CHECK (weight_kg IS NULL OR weight_kg > 0)
);

COMMENT ON TABLE medical_records IS 'Ficha médica general. Datos sensibles: solo el propietario puede consultarlos.';

-- ====================================================================
--  TABLA: vaccinations
--  Historial de vacunaciones.
-- ====================================================================
CREATE TABLE vaccinations (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    vaccine_name    VARCHAR(100) NOT NULL,
    administered_at DATE        NOT NULL,
    next_due_date   DATE,               -- Fecha de próxima dosis (NULL = dosis única)
    batch_number    VARCHAR(50),
    administered_by VARCHAR(150),       -- Nombre del veterinario
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT vaccination_dates CHECK (next_due_date IS NULL OR next_due_date > administered_at)
);

COMMENT ON TABLE vaccinations IS 'Registro de vacunas aplicadas y fechas de refuerzo.';

-- ====================================================================
--  TABLA: medications
--  Medicamentos activos o históricos de la mascota.
-- ====================================================================
CREATE TABLE medications (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    name            VARCHAR(150) NOT NULL,
    dosage          VARCHAR(100),           -- "5 mg cada 12 horas"
    start_date      DATE        NOT NULL,
    end_date        DATE,                   -- NULL si es crónico / indefinido
    prescribed_by   VARCHAR(150),
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT medication_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

COMMENT ON TABLE medications IS 'Medicamentos de la mascota. is_active=TRUE para tratamientos en curso.';

-- ====================================================================
--  TABLA: emergency_contacts
--  Contactos a notificar si la mascota se extravía.
-- ====================================================================
CREATE TABLE emergency_contacts (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id      UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    full_name   VARCHAR(150) NOT NULL,
    relationship VARCHAR(80),           -- "Vecino", "Familiar", "Veterinario"
    phone       VARCHAR(25) NOT NULL,
    email       VARCHAR(255),
    is_primary  BOOLEAN     NOT NULL DEFAULT FALSE,
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT contact_email_format CHECK (
        email IS NULL OR email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'
    )
);

COMMENT ON TABLE emergency_contacts IS 'Personas a contactar en caso de extravío. Al menos un contacto debería tener is_primary=TRUE.';

-- ====================================================================
--  TABLA: lost_pet_reports
--  Reporte formal de mascota extraviada con información para recuperarla.
-- ====================================================================
CREATE TABLE lost_pet_reports (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id              UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    reported_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at        TIMESTAMPTZ,
    last_seen_lat       NUMERIC(10, 7),
    last_seen_lon       NUMERIC(10, 7),
    last_seen_address   TEXT,
    reward_description  TEXT,           -- "Se ofrece recompensa" (sin montos para privacidad)
    public_contact      VARCHAR(255),   -- Teléfono/correo público para quien encuentre a la mascota
    description_for_finder TEXT,        -- "Lleva collar rojo, responde a 'Max'"
    is_found            BOOLEAN     NOT NULL DEFAULT FALSE,
    found_at            TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT lost_report_found_consistency CHECK (
        (is_found = FALSE AND found_at IS NULL) OR
        (is_found = TRUE  AND found_at IS NOT NULL)
    )
);

COMMENT ON TABLE lost_pet_reports IS 'Reporte de extravío. description_for_finder es información pública para ayudar a recuperar la mascota.';

-- ====================================================================
--  TABLAS DE IA — Preparadas para módulos de inteligencia artificial
--  NOTA ACADÉMICA: Estas tablas almacenan resultados de análisis de IA.
--  El modelo de IA en sí (Python/TensorFlow/scikit-learn) es un componente
--  externo que alimenta estas tablas. No se simulan predicciones reales.
-- ====================================================================

-- Patrones de movimiento aprendidos por mascota
CREATE TABLE ai_movement_patterns (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    pattern_type    VARCHAR(50) NOT NULL,
    -- 'daily_routine'   : rutina diaria detectada
    -- 'frequent_zone'   : zona visitada con frecuencia
    -- 'unusual_time'    : movimiento fuera del horario normal
    description     TEXT,
    confidence      NUMERIC(4, 3),          -- 0.000 a 1.000
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    data_from       TIMESTAMPTZ,            -- Inicio del período analizado
    data_to         TIMESTAMPTZ,            -- Fin del período analizado
    model_version   VARCHAR(30),            -- Versión del modelo de IA usado
    metadata        JSONB,                  -- Datos adicionales del modelo (flexibles)

    CONSTRAINT ai_confidence_range CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
    CONSTRAINT ai_pattern_type_values CHECK (
        pattern_type IN ('daily_routine','frequent_zone','unusual_time','activity_change','other')
    )
);

COMMENT ON TABLE  ai_movement_patterns IS 'Resultados de análisis de patrones de movimiento generados por el módulo de IA externo.';
COMMENT ON COLUMN ai_movement_patterns.confidence IS 'Nivel de confianza del modelo (0-1). Solo informativo; no reemplaza supervisión humana.';

-- Anomalías detectadas por IA
CREATE TABLE ai_anomaly_detections (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id          UUID        NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    alert_id        UUID        REFERENCES alerts(id) ON DELETE SET NULL,
    anomaly_type    VARCHAR(80) NOT NULL,
    description     TEXT        NOT NULL,
    severity_score  NUMERIC(4, 3),          -- 0.000 a 1.000
    detected_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    location_lat    NUMERIC(10, 7),
    location_lon    NUMERIC(10, 7),
    is_confirmed    BOOLEAN,                -- NULL=pendiente revisión, TRUE/FALSE=revisado por humano
    model_version   VARCHAR(30),
    metadata        JSONB,

    CONSTRAINT ai_severity_range CHECK (severity_score IS NULL OR severity_score BETWEEN 0 AND 1)
);

COMMENT ON TABLE ai_anomaly_detections IS 'Comportamientos inusuales detectados por IA. Siempre requieren revisión humana (is_confirmed).';

-- ====================================================================
--  TABLA: audit_log
--  Registro de seguridad: quién hizo qué y cuándo.
-- ====================================================================
CREATE TABLE audit_log (
    id              BIGSERIAL   PRIMARY KEY,
    user_id         UUID        REFERENCES users(id) ON DELETE SET NULL,
    action          VARCHAR(60) NOT NULL,
    -- 'USER_LOGIN', 'USER_LOGOUT', 'PET_CREATED', 'PET_UPDATED',
    -- 'ALERT_CREATED', 'DATA_EXPORT', 'PASSWORD_CHANGED', etc.
    entity_type     VARCHAR(60),
    entity_id       UUID,
    ip_address      INET,
    user_agent      VARCHAR(400),
    details         JSONB,              -- Información adicional del evento
    performed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_log IS 'Registro de auditoría de seguridad y acciones de usuario. Nunca modificar ni borrar registros de este log.';

-- ====================================================================
--  ÍNDICES — Optimización de consultas críticas
-- ====================================================================

-- Autenticación y sesiones
CREATE INDEX idx_users_email           ON users(email);
CREATE INDEX idx_refresh_tokens_user   ON refresh_tokens(user_id, expires_at);

-- Mascotas por propietario (consulta más frecuente)
CREATE INDEX idx_pets_owner            ON pets(owner_id);
CREATE INDEX idx_pets_status           ON pets(status) WHERE status IN ('away', 'lost');

-- Dispositivos
CREATE INDEX idx_devices_pet           ON tracker_devices(pet_id);
CREATE INDEX idx_devices_uid           ON tracker_devices(device_uid);

-- Historial de ubicación — Índice por mascota + tiempo (crítico por volumen)
CREATE INDEX idx_location_pet_time     ON location_history(pet_id, recorded_at DESC);
CREATE INDEX idx_location_recorded_at  ON location_history(recorded_at DESC);

-- Zonas seguras
CREATE INDEX idx_zones_pet             ON safe_zones(pet_id) WHERE is_active = TRUE;

-- Alertas no resueltas
CREATE INDEX idx_alerts_pet            ON alerts(pet_id, created_at DESC);
CREATE INDEX idx_alerts_unresolved     ON alerts(pet_id) WHERE is_resolved = FALSE;

-- Datos médicos
CREATE INDEX idx_vaccinations_pet      ON vaccinations(pet_id, next_due_date);
CREATE INDEX idx_medications_pet       ON medications(pet_id) WHERE is_active = TRUE;

-- IA
CREATE INDEX idx_ai_patterns_pet       ON ai_movement_patterns(pet_id, detected_at DESC);
CREATE INDEX idx_ai_anomalies_pet      ON ai_anomaly_detections(pet_id, detected_at DESC);

-- Auditoría
CREATE INDEX idx_audit_user            ON audit_log(user_id, performed_at DESC);

