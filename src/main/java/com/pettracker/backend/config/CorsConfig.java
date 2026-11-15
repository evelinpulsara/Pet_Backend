package com.pettracker.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * CORS: el navegador solo deja que la app llame a este backend si viene de un
 * origen permitido (la URL del frontend en Vercel, variable CORS_ORIGINS).
 * El collar GPS no es un navegador, así que CORS no le afecta.
 */
@Configuration
public class CorsConfig implements WebMvcConfigurer {
    private final AppProperties props;

    public CorsConfig(AppProperties props) {
        this.props = props;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns(props.corsOrigins().stream().map(String::trim).toArray(String[]::new))
                .allowedMethods("GET", "POST", "OPTIONS")
                .allowedHeaders("*")
                .maxAge(3600);
    }
}
