package com.pettracker.backend.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Configuración leída de application.properties / variables de entorno.
 *
 * Si una variable existe pero está vacía (por ejemplo CORS_ORIGINS="" en Render),
 * Spring entrega null: aquí se cambia por un valor por defecto para que el
 * servidor siempre arranque.
 */
@ConfigurationProperties(prefix = "app")
public record AppProperties(
        List<String> corsOrigins,
        String geminiApiKey,
        List<String> geminiModels,
        String supabaseUrl,
        String supabaseKey,
        Integer aiRequestsPerMinute) {

    /** Orígenes permitidos si no se configura CORS_ORIGINS: desarrollo local y Vercel. */
    public static final List<String> DEFAULT_CORS = List.of("http://localhost:*", "https://*.vercel.app");
    public static final List<String> DEFAULT_MODELS =
            List.of("gemini-3-flash-preview", "gemini-3.1-flash-lite", "gemini-3.8-flash");

    public AppProperties {
        corsOrigins = clean(corsOrigins, DEFAULT_CORS);
        geminiModels = clean(geminiModels, DEFAULT_MODELS);
        geminiApiKey = geminiApiKey == null ? "" : geminiApiKey.trim();
        supabaseUrl = orDefault(supabaseUrl, "https://zcsfkltvilypjxocoojz.supabase.co");
        supabaseKey = orDefault(supabaseKey, "sb_publishable_ng-YqVkaUzj2SG0Op8VpnA_cjt3AgWm"); // clave PÚBLICA
        if (aiRequestsPerMinute == null || aiRequestsPerMinute <= 0) aiRequestsPerMinute = 20;
    }

    private static String orDefault(String v, String fallback) {
        return v == null || v.isBlank() ? fallback : v.trim();
    }

    /** Quita espacios, entradas vacías y la "/" final de cada URL; si no queda nada, usa el valor por defecto. */
    private static List<String> clean(List<String> values, List<String> fallback) {
        if (values == null) return fallback;
        List<String> out = values.stream()
                .filter(v -> v != null && !v.isBlank())
                .map(String::trim)
                .map(v -> v.endsWith("/") ? v.substring(0, v.length() - 1) : v)
                .toList();
        return out.isEmpty() ? fallback : out;
    }

    public boolean geminiConfigured() {
        return !geminiApiKey.isBlank();
    }
}
