# PetTracker — Backend

Backend del sistema de rastreo de mascotas con IA.
El frontend (Flutter) vive en otro repositorio: https://github.com/evelinpulsara/Controller_pet

**Stack:** Spring Boot 3.3.x · Java 21 · PostgreSQL 15+ · Flyway · JWT

## Servidor (Spring Boot) — se despliega en Render

Hace de intermediario seguro entre la app (Vercel) y los servicios externos:

| Endpoint | Qué hace |
|---|---|
| `GET /api/health` | Estado del servicio (Render lo usa para saber si está vivo) |
| `POST /api/ai/lost-alert` | La IA escribe el aviso para el dueño y el mensaje de WhatsApp |
| `POST /api/ai/poster` | La IA escribe el cartel de "Se busca" |
| `POST /api/ai/day-summary/stream` | Resumen del día por **SSE** (`text/event-stream`) |
| `POST /api/collar/location` | El collar GPS (Arduino) envía su ubicación; se valida y se guarda en Supabase |

- La clave de Gemini vive **solo aquí** (variable `GEMINI_API_KEY`), nunca en la app.
- **CORS:** solo acepta pedidos del navegador que vengan del frontend (variable `CORS_ORIGINS`).
- Límite de pedidos de IA por IP (protege la clave de abusos).
- Validación de datos de entrada con Bean Validation.

**Correr en local:** `GEMINI_API_KEY=... mvn spring-boot:run` → http://localhost:8080/api/health
**Pruebas:** `mvn test`

**Variables de entorno en Render:**

| Variable | Valor |
|---|---|
| `GEMINI_API_KEY` | Clave de Google AI Studio (secreta) |
| `CORS_ORIGINS` | URL del frontend en Vercel, ej. `https://controllerpet.vercel.app` (varias separadas por coma) |

Ejemplo del collar:
```
POST https://TU-BACKEND.onrender.com/api/collar/location
Content-Type: application/json

{"deviceUid":"TRK-1001","deviceKey":"clave-secreta-123","lat":1.2136,"lon":-77.2811,"accuracy":5,"battery":87}
```

## Base de datos en Supabase (la que se usa ahora)

El proyecto de Supabase se comparte con otras apps; cada una vive en su propio esquema:

| Esquema | App |
|---|---|
| `pettracker` | Esta app (mascotas) |
| `restotime` | App del restaurante — no tocar |
| `public` | App de Spring Boot — no tocar |

1. Supabase → **SQL Editor** → pega `supabase/pettracker_schema.sql` → **Run**.
   Se puede volver a ejecutar sin perder datos.
2. **Settings → API → Exposed schemas**: agrega `pettracker`.
3. La app usa solo la **clave pública** (anon / publishable). La `service_role` nunca va en la app.

Seguridad: cada tabla tiene Row Level Security; cada dueño solo ve sus mascotas.
Al registrarse desde PetTracker se envía `app: 'pettracker'` en la metadata del usuario
y se crea su perfil en `pettracker.profiles` (las otras apps no se ven afectadas).

### Collar GPS (por ejemplo, con Arduino)
El collar envía su ubicación sin iniciar sesión, validándose con su código y una clave secreta
que el dueño le asigna desde la app (`pettracker.set_device_key`):

```
POST https://TU-PROYECTO.supabase.co/rest/v1/rpc/report_location
apikey: <clave pública>
Content-Type: application/json
Content-Profile: pettracker

{"p_device_uid":"TRK-1001","p_device_key":"clave-secreta","p_lat":1.2136,"p_lon":-77.2811,"p_accuracy":5,"p_battery":87}
```

> Los archivos de `sql/` y `spring-config/` son el diseño original para Spring Boot + Flyway.
> Para Supabase se usa `supabase/pettracker_schema.sql`.

## Estructura

```
sql/
  V1__schema.sql          # Esquema de la base de datos (migración Flyway)
  V2__sample_data.sql     # Datos de prueba ficticios
spring-config/
  pom.xml                           # Dependencias Maven
  application.properties.template   # Plantilla de configuración (sin credenciales)
docs/                     # Documentación
```

## Uso

1. Crea una base de datos PostgreSQL (local, Neon o Supabase).
2. En el proyecto Spring Boot:
   - Copia `spring-config/pom.xml` a la raíz del proyecto.
   - Copia `spring-config/application.properties.template` a `src/main/resources/application.properties`
     y define las variables de entorno (`DB_HOST`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`, ...).
   - Copia los scripts de `sql/` a `src/main/resources/db/migration/` para que Flyway los aplique.
3. Ejecuta `./mvnw spring-boot:run`.

> `application.properties` está en `.gitignore`: nunca subas credenciales al repositorio.
