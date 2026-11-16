package com.pettracker.backend;

import static org.assertj.core.api.Assertions.assertThat;

import com.pettracker.backend.config.AppProperties;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(properties = {
    "app.cors-origins=", "app.gemini-models=", "app.ai-requests-per-minute=",
    "app.supabase-url=", "app.supabase-key=", "app.gemini-api-key="})
class EmptyEnvTests {
    @Autowired AppProperties props;

    @Test
    void arrancaConVariablesVacias() {
        assertThat(props.corsOrigins()).isEqualTo(AppProperties.DEFAULT_CORS);
        assertThat(props.geminiModels()).isNotEmpty();
        assertThat(props.aiRequestsPerMinute()).isEqualTo(20);
        assertThat(props.supabaseUrl()).startsWith("https://");
        assertThat(props.geminiConfigured()).isFalse();
    }
}
