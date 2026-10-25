# PetTracker — Backend

Backend del sistema de rastreo de mascotas con IA.
El frontend (Flutter) vive en otro repositorio: https://github.com/evelinpulsara/Controller_pet

**Stack:** Spring Boot 3.3.x · Java 21 · PostgreSQL 15+ · Flyway · JWT


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
