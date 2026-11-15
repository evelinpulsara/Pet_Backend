package com.pettracker.backend.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pettracker.backend.ai.AiDtos.DaySummaryRequest;
import com.pettracker.backend.ai.AiDtos.DaySummaryResponse;
import com.pettracker.backend.ai.AiDtos.LostPetRequest;
import com.pettracker.backend.ai.AiDtos.LostPetResponse;
import com.pettracker.backend.ai.AiDtos.PosterResponse;
import java.util.List;
import java.util.Locale;
import java.util.function.Consumer;
import org.springframework.stereotype.Service;

/**
 * La IA de PetTracker: arma las instrucciones (prompts) para Gemini y, si la IA
 * no responde, devuelve textos de respaldo para que la app nunca se quede sin respuesta.
 */
@Service
public class PetAiService {
    private final GeminiClient gemini;
    private final ObjectMapper json;

    public PetAiService(GeminiClient gemini, ObjectMapper json) {
        this.gemini = gemini;
        this.json = json;
    }

    private static boolean es(String locale) {
        return !"en".equals(locale);
    }

    private static String lang(String locale) {
        return es(locale) ? "español (como se habla en Latinoamérica)" : "English";
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }

    private JsonNode parseJson(String text) {
        try {
            return json.readTree(text);
        } catch (Exception e) {
            return null;
        }
    }

    // ── Aviso de mascota perdida ──────────────────────────────────────────────
    public LostPetResponse lostPet(LostPetRequest r) {
        String prompt = """
                Eres el asistente de emergencias de PetTracker, una app que rastrea mascotas con un collar GPS.
                La mascota acaba de salir de su zona segura. Escribe dos textos en %s:

                1. "owner_alert": aviso corto para el dueño dentro de la app (máximo 2 frases). Dile qué pasó
                   con datos concretos y que ya preparaste un mensaje para sus contactos de emergencia.
                   Si la batería del collar está baja (menos de 20%%), adviértelo porque podría perder el rastro.
                2. "contact_message": mensaje de WhatsApp que el dueño enviará a sus vecinos, familiares y amigos,
                   escrito en primera persona como si lo escribiera el dueño. Debe empezar con "🚨", decir que la
                   mascota se salió, describirla (nombre, especie, raza, edad) para que la reconozcan, la hora,
                   y pedir que avisen si la ven y que ayuden a buscarla. Tono cálido y urgente, máximo 4 frases,
                   puede tener 1 o 2 emojis. NO incluyas enlaces ni coordenadas (la app agrega la ubicación después).

                No inventes datos que no estén aquí (ni color, ni teléfono, ni dirección).
                Responde SOLO con un JSON así: {"owner_alert": "...", "contact_message": "..."}

                Datos:
                - Mascota: %s, %s, raza %s, %d años.
                - Dueño: %s.
                - Zona segura: "%s". Está a unos %d m fuera de ella.
                - Hora en que salió: %s.
                - Batería del collar GPS: %d%%.
                """.formatted(lang(r.locale()), r.petName(), nz(r.species()), nz(r.breed()), r.age(), nz(r.ownerName()),
                nz(r.zoneName()), Math.round(r.distanceOutsideMeters()), nz(r.time()), r.batteryLevel());
        var ai = gemini.generate(prompt, true).map(this::parseJson);
        if (ai.isPresent() && ai.get() != null) {
            String owner = ai.get().path("owner_alert").asText("").trim();
            String contact = ai.get().path("contact_message").asText("").trim();
            if (!owner.isEmpty() && !contact.isEmpty()) return new LostPetResponse(owner, contact, true);
        }
        long dist = Math.round(r.distanceOutsideMeters());
        String sp = nz(r.species()), br = nz(r.breed());
        return es(r.locale())
                ? new LostPetResponse(
                        r.petName() + " salió de la zona segura \"" + nz(r.zoneName()) + "\" y está a unos " + dist
                                + " m fuera de ella. Revisa su ubicación en el mapa y avisa a tus contactos para que te ayuden a buscarlo.",
                        "🚨 ¡Alerta! " + r.petName() + " (" + sp + ", " + br + ") se salió de casa a las " + nz(r.time())
                                + ". Si lo ves por la zona, por favor avísame por aquí. ¡Gracias por ayudarme a encontrarlo! 🐾",
                        false)
                : new LostPetResponse(
                        r.petName() + " left the safe zone \"" + nz(r.zoneName()) + "\" and is about " + dist
                                + " m outside it. Check the map and alert your contacts so they can help you look.",
                        "🚨 Alert! " + r.petName() + " (" + sp + ", " + br + ") got out of the house at " + nz(r.time())
                                + ". If you see them around, please let me know here. Thanks for helping me find them! 🐾",
                        false);
    }

    // ── Cartel de "Se busca" ──────────────────────────────────────────────────
    public PosterResponse poster(LostPetRequest r) {
        String prompt = """
                Escribe el texto de un cartel de "Se busca" para una mascota perdida, en %s.
                Responde SOLO con JSON: {"headline": "...", "description": "..."}
                - "headline": frase corta y emotiva (máximo 7 palabras) que incluya el nombre.
                - "description": 2 o 3 frases para que la gente la reconozca y llame. Incluye especie, raza,
                  edad, dónde y a qué hora se perdió. No inventes color, tamaño, collar ni recompensa.
                Datos: %s, %s, raza %s, %d años. Se perdió a las %s cerca de "%s".
                """.formatted(lang(r.locale()), r.petName(), nz(r.species()), nz(r.breed()), r.age(), nz(r.time()), nz(r.zoneName()));
        var ai = gemini.generate(prompt, true).map(this::parseJson);
        if (ai.isPresent() && ai.get() != null) {
            String h = ai.get().path("headline").asText("").trim(), d = ai.get().path("description").asText("").trim();
            if (!h.isEmpty() && !d.isEmpty()) return new PosterResponse(h, d, true);
        }
        String sp = nz(r.species()).toLowerCase(Locale.ROOT);
        return es(r.locale())
                ? new PosterResponse("¡Ayúdame a encontrar a " + r.petName() + "!",
                        r.petName() + " es un " + sp + " " + nz(r.breed()) + " de " + r.age() + " años. Se perdió hoy a las "
                                + nz(r.time()) + " cerca de \"" + nz(r.zoneName()) + "\". Es muy querido en casa; si lo ves, por favor llámame.",
                        false)
                : new PosterResponse("Help me find " + r.petName() + "!",
                        r.petName() + " is a " + r.age() + "-year-old " + nz(r.breed()) + " " + sp + ". Went missing today at "
                                + nz(r.time()) + " near \"" + nz(r.zoneName()) + "\". Much loved at home; if you see them, please call me.",
                        false);
    }

    // ── Resumen del día ───────────────────────────────────────────────────────
    private String summaryPrompt(DaySummaryRequest d) {
        List<String> places = d.placesVisited() == null ? List.of() : d.placesVisited();
        List<String> unusual = d.unusual() == null ? List.of() : d.unusual();
        return """
                Eres el asistente de PetTracker. Escribe en %s un resumen cálido y breve (2 o 3 frases,
                texto plano, sin markdown ni comillas) de cómo fue el día de la mascota, como si se lo contaras a su dueño.
                Usa solo estos datos, no inventes lugares ni actividades. Si hubo algo inusual, menciónalo con calma.
                - Mascota: %s (%s).
                - Distancia: %.2f km de una meta de %.1f km.
                - Minutos activo: %d.
                - Paseos: %d (total %d min).
                - Minutos fuera de sus zonas seguras: %d.
                - Lugares (zonas) donde estuvo: %s.
                - Alertas hoy: %d.
                - Cosas inusuales: %s.
                """.formatted(lang(d.locale()), d.petName(), nz(d.species()), d.distanceMeters() / 1000, d.goalMeters() / 1000,
                d.activeMinutes(), d.walks(), d.walkMinutes(), d.minutesOutside(),
                places.isEmpty() ? "ninguno registrado" : String.join(", ", places), d.alertsToday(),
                unusual.isEmpty() ? "ninguna" : String.join("; ", unusual));
    }

    public String summaryFallback(DaySummaryRequest d) {
        boolean es = es(d.locale());
        String km = d.distanceMeters() < 1000
                ? Math.round(d.distanceMeters()) + " m"
                : String.format(Locale.ROOT, "%.1f km", d.distanceMeters() / 1000);
        long pct = d.goalMeters() <= 0 ? 0 : Math.round(d.distanceMeters() / d.goalMeters() * 100);
        String walks = d.walks() == 0
                ? (es ? "No salió de paseo." : "No walks today.")
                : (es ? "Salió a " + d.walks() + " paseo(s) (" + d.walkMinutes() + " min)." : "Went on " + d.walks() + " walk(s) (" + d.walkMinutes() + " min).");
        String out = d.minutesOutside() > 0
                ? (es ? " Estuvo " + d.minutesOutside() + " min fuera de sus zonas seguras." : " Spent " + d.minutesOutside() + " min outside safe zones.")
                : (es ? " Estuvo siempre en sus zonas seguras." : " Stayed in safe zones all day.");
        return es
                ? d.petName() + " recorrió " + km + " hoy (" + pct + "% de su meta) y estuvo activo " + d.activeMinutes() + " min. " + walks + out
                : d.petName() + " covered " + km + " today (" + pct + "% of the goal) and was active for " + d.activeMinutes() + " min. " + walks + out;
    }

    public DaySummaryResponse daySummary(DaySummaryRequest d) {
        return gemini.generate(summaryPrompt(d), false)
                .map(t -> new DaySummaryResponse(t, true))
                .orElseGet(() -> new DaySummaryResponse(summaryFallback(d), false));
    }

    /** Resumen por partes (SSE). Devuelve false si no hubo IA (se usará el respaldo). */
    public boolean daySummaryStream(DaySummaryRequest d, Consumer<String> onText) {
        return gemini.stream(summaryPrompt(d), onText);
    }
}
