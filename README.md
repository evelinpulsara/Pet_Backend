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

