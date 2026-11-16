# PetTracker — Backend

Servidor y base de datos de PetTracker.

- **Frontend:** https://github.com/evelinpulsara/Controller_pet
- **Servidor en línea:** `https://ENLACE-DE-RENDER/api/health`
- **Probar la app:** abre el frontend y entra con **"Probar con la cuenta demo"**.

**Stack:** Spring Boot 3.5 · Java 21 · Docker (Render) · Supabase (PostgreSQL)

## Qué se implementó
| Parte | Qué hace |
|---|---|
| Servidor de IA | Intermediario seguro con Google Gemini. La clave vive solo aquí, nunca en la app. |
| SSE | `SseEmitter` reenvía el resumen del día por partes (`text/event-stream`) |
| Collar GPS | Recibe y valida la ubicación del collar y la guarda en Supabase mediante RPC |
| Seguridad | CORS solo para el frontend, límite de pedidos de IA por IP y validación con Bean Validation |
| Base de datos | Esquema `pettracker` con Row Level Security: cada dueño ve solo sus datos |
| Contrato del API | `api/openapi.yaml` (Contract-First) |
| Pruebas | `mvn test`: salud, CORS, validación, respaldo de la IA y variables vacías |

## Endpoints
| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/api/health` | Estado del servicio |
| POST | `/api/ai/lost-alert` | Aviso para el dueño y mensaje de WhatsApp |
| POST | `/api/ai/poster` | Texto del cartel de "Se busca" |
| POST | `/api/ai/day-summary/stream` | Resumen del día por SSE |
| POST | `/api/collar/location` | El collar envía su ubicación |

Si Gemini no responde, el servidor devuelve textos de respaldo y la app sigue funcionando.

## Estructura
```
src/main/java/com/pettracker/backend/
  ai/        AiController → PetAiService → GeminiClient
  collar/    CollarController
  config/    AppProperties, CorsConfig, RateLimiter
  web/       HealthController, ApiExceptionHandler
supabase/    pettracker_schema.sql (tablas, RLS, funciones RPC, Realtime)
api/         openapi.yaml
sql/, spring-config/   diseño inicial con Flyway (referencia)
```
**Patrones:** arquitectura por capas (Controller → Service → Client), inyección de dependencias de Spring, y `GeminiClient` como adaptador de la API externa.

## Correr y desplegar
```
GEMINI_API_KEY=... mvn spring-boot:run     # http://localhost:8080/api/health
mvn test
```
Render lo construye con el `Dockerfile`.

| Variable | Valor |
|---|---|
| `GEMINI_API_KEY` | Clave de Google AI Studio (secreta) |
| `CORS_ORIGINS` | URL del frontend en Vercel |

## Base de datos (Supabase)
1. En **SQL Editor**, ejecuta `supabase/pettracker_schema.sql`.
2. En **Settings → API → Exposed schemas**, agrega `pettracker`.
3. La app usa solo la clave **pública**; la `service_role` nunca va en el código.

El proyecto de Supabase se comparte con otras apps. PetTracker usa solo el esquema `pettracker`; no se deben modificar `public` ni `restotime`.
