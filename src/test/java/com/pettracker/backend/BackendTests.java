package com.pettracker.backend;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/** Pruebas sin internet: Gemini sin clave (usa respaldo) y validación de datos. */
@SpringBootTest(properties = {"app.gemini-api-key=", "app.cors-origins=https://pettracker.vercel.app"})
@AutoConfigureMockMvc
class BackendTests {
    @Autowired MockMvc mvc;

    @Test
    void healthResponde() throws Exception {
        mvc.perform(get("/api/health")).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("ok"));
    }

    @Test
    void corsSoloPermiteElFrontend() throws Exception {
        mvc.perform(options("/api/ai/poster").header("Origin", "https://pettracker.vercel.app")
                        .header("Access-Control-Request-Method", "POST"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "https://pettracker.vercel.app"));
        mvc.perform(options("/api/ai/poster").header("Origin", "https://sitio-malicioso.com")
                        .header("Access-Control-Request-Method", "POST"))
                .andExpect(status().isForbidden());
    }

    @Test
    void avisoDeMascotaPerdidaConRespaldo() throws Exception {
        mvc.perform(post("/api/ai/lost-alert").contentType(MediaType.APPLICATION_JSON).content("""
                        {"petName":"Luna","species":"Perro","breed":"Labrador","age":3,"ownerName":"Evelin",
                         "zoneName":"Casa","distanceOutsideMeters":40,"batteryLevel":80,"time":"10:30","locale":"es"}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.contactMessage").value(org.hamcrest.Matchers.startsWith("🚨")))
                .andExpect(jsonPath("$.fromAi").value(false));
    }

    @Test
    void validaDatosInvalidos() throws Exception {
        mvc.perform(post("/api/ai/lost-alert").contentType(MediaType.APPLICATION_JSON).content("""
                        {"petName":"","age":300,"batteryLevel":150,"time":"ayer","locale":"fr"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("Datos inválidos"));
        mvc.perform(post("/api/collar/location").contentType(MediaType.APPLICATION_JSON).content("""
                        {"deviceUid":"TRK-1","deviceKey":"corta","lat":120,"lon":-77}"""))
                .andExpect(status().isBadRequest());
    }
}
