package com.pettracker.backend.web;

import com.pettracker.backend.config.AppProperties;
import java.time.Instant;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Estado del servicio (Render lo usa para saber si está vivo). */
@RestController
public class HealthController {
    private final AppProperties props;

    public HealthController(AppProperties props) {
        this.props = props;
    }

    @GetMapping({"/", "/api/health"})
    public Map<String, Object> health() {
        return Map.of(
                "service", "pettracker-backend",
                "status", "ok",
                "ai", props.geminiConfigured() ? "configurada" : "sin clave (usa respuestas de respaldo)",
                "time", Instant.now().toString());
    }
}
