# ---- Etapa 1: compilar con Maven ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package

# ---- Etapa 2: imagen liviana solo con Java para ejecutar ----
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/pettracker-backend.jar app.jar
# Render asigna el puerto en la variable PORT (application.properties la usa).
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseSerialGC -Xss512k"
EXPOSE 8080
CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
