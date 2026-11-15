package com.pettracker.backend.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pettracker.backend.config.AppProperties;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import java.util.Optional;
import java.util.function.Consumer;
import java.util.stream.Stream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Cliente de Google Gemini. La clave (GEMINI_API_KEY) vive solo en el servidor.
 * Prueba los modelos en orden: si uno está saturado o no existe, usa el siguiente.
 */
@Component
public class GeminiClient {
    private static final Logger log = LoggerFactory.getLogger(GeminiClient.class);
    private static final String BASE = "https://generativelanguage.googleapis.com/v1beta/models/";

    private final AppProperties props;
    private final ObjectMapper json;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

    public GeminiClient(AppProperties props, ObjectMapper json) {
        this.props = props;
        this.json = json;
    }

    public boolean configured() {
        return props.geminiConfigured();
    }

    private String body(String prompt, boolean asJson) throws Exception {
        var config = asJson
                ? Map.of("temperature", 0.6, "maxOutputTokens", 2048, "responseMimeType", "application/json")
                : Map.of("temperature", 0.6, "maxOutputTokens", 2048);
        return json.writeValueAsString(Map.of(
                "contents", new Object[] {Map.of("role", "user", "parts", new Object[] {Map.of("text", prompt)})},
                "generationConfig", config));
    }

    private HttpRequest.Builder request(String url) {
        return HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(20))
                .header("Content-Type", "application/json")
                .header("x-goog-api-key", props.geminiApiKey());
    }

    /** Texto de las partes de la respuesta (sin el "pensamiento" del modelo). */
    private String textOf(JsonNode root) {
        var sb = new StringBuilder();
        for (JsonNode p : root.path("candidates").path(0).path("content").path("parts")) {
            if (!p.path("thought").asBoolean(false) && p.has("text")) sb.append(p.get("text").asText());
        }
        return sb.toString();
    }

    /** Pide una respuesta completa. Vacío si ningún modelo respondió. */
    public Optional<String> generate(String prompt, boolean asJson) {
        if (!configured()) return Optional.empty();
        for (String model : props.geminiModels()) {
            try {
                var res = http.send(
                        request(BASE + model.trim() + ":generateContent")
                                .POST(HttpRequest.BodyPublishers.ofString(body(prompt, asJson)))
                                .build(),
                        HttpResponse.BodyHandlers.ofString());
                if (res.statusCode() != 200) throw new IllegalStateException("HTTP " + res.statusCode());
                String text = textOf(json.readTree(res.body())).trim();
                if (!text.isEmpty()) return Optional.of(text);
            } catch (Exception e) {
                log.warn("Gemini {} no respondió: {}", model, e.getMessage());
            }
        }
        return Optional.empty();
    }

    /**
     * Pide la respuesta por SSE (streamGenerateContent?alt=sse) y llama a
     * [onText] con el texto acumulado cada vez que llega un pedazo.
     * Devuelve true si llegó algo.
     */
    public boolean stream(String prompt, Consumer<String> onText) {
        if (!configured()) return false;
        for (String model : props.geminiModels()) {
            var acc = new StringBuilder();
            try {
                var res = http.send(
                        request(BASE + model.trim() + ":streamGenerateContent?alt=sse")
                                .header("Accept", "text/event-stream")
                                .POST(HttpRequest.BodyPublishers.ofString(body(prompt, false)))
                                .build(),
                        HttpResponse.BodyHandlers.ofLines());
                if (res.statusCode() != 200) throw new IllegalStateException("HTTP " + res.statusCode());
                try (Stream<String> lines = res.body()) {
                    for (String line : (Iterable<String>) lines::iterator) {
                        if (!line.startsWith("data:")) continue;
                        String piece = textOf(json.readTree(line.substring(5).trim()));
                        if (piece.isEmpty()) continue;
                        acc.append(piece);
                        onText.accept(acc.toString().stripLeading());
                    }
                }
                if (!acc.toString().isBlank()) return true;
            } catch (Exception e) {
                log.warn("Gemini (SSE) {} no respondió: {}", model, e.getMessage());
                if (!acc.toString().isBlank()) return true;
            }
        }
        return false;
    }
}
