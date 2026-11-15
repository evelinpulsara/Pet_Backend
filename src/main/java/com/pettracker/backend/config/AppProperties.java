package com.pettracker.backend.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** Configuración leída de application.properties / variables de entorno. */
@ConfigurationProperties(prefix = "app")
public record AppProperties(
        List<String> corsOrigins,
        String geminiApiKey,
        List<String> geminiModels,
        String supabaseUrl,
        String supabaseKey,
        int aiRequestsPerMinute) {

    public boolean geminiConfigured() {
        return geminiApiKey != null && !geminiApiKey.isBlank();
    }
}
