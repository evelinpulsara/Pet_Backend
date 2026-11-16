package com.pettracker.backend.ai;

import com.pettracker.backend.ai.AiDtos.DaySummaryRequest;
import com.pettracker.backend.ai.AiDtos.DaySummaryResponse;
import com.pettracker.backend.ai.AiDtos.LostPetRequest;
import com.pettracker.backend.ai.AiDtos.LostPetResponse;
import com.pettracker.backend.ai.AiDtos.PosterResponse;
import com.pettracker.backend.config.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequestMapping("/api/ai")
public class AiController {
    private final PetAiService ai;
    private final RateLimiter limiter;
    private final ExecutorService streams = Executors.newVirtualThreadPerTaskExecutor();

    public AiController(PetAiService ai, RateLimiter limiter) {
        this.ai = ai;
        this.limiter = limiter;
    }

    private void checkLimit(HttpServletRequest req) {
        String fwd = req.getHeader("X-Forwarded-For");
        String ip = fwd != null && !fwd.isBlank() ? fwd.split(",")[0].trim() : req.getRemoteAddr();
        if (!limiter.allow(ip)) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "Demasiados pedidos, intenta en un minuto");
        }
    }

    @PostMapping("/lost-alert")
    public LostPetResponse lostAlert(@Valid @RequestBody LostPetRequest r, HttpServletRequest req) {
        checkLimit(req);
        return ai.lostPet(r);
    }

    @PostMapping("/poster")
    public PosterResponse poster(@Valid @RequestBody LostPetRequest r, HttpServletRequest req) {
        checkLimit(req);
        return ai.poster(r);
    }

    @PostMapping("/day-summary")
    public DaySummaryResponse daySummary(@Valid @RequestBody DaySummaryRequest d, HttpServletRequest req) {
        checkLimit(req);
        return ai.daySummary(d);
    }

    @PostMapping(value = "/day-summary/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter daySummaryStream(@Valid @RequestBody DaySummaryRequest d, HttpServletRequest req) {
        checkLimit(req);
        var emitter = new SseEmitter(60_000L);
        streams.submit(() -> {
            try {
                boolean got = ai.daySummaryStream(d, text -> {
                    try {
                        emitter.send(SseEmitter.event().name("message").data(Map.of("text", text), MediaType.APPLICATION_JSON));
                    } catch (Exception e) {
                        throw new IllegalStateException(e);
                    }
                });
                if (!got) {
                    emitter.send(SseEmitter.event().name("message")
                            .data(Map.of("text", ai.summaryFallback(d)), MediaType.APPLICATION_JSON));
                }
                emitter.send(SseEmitter.event().name("done").data("{}"));
                emitter.complete();
            } catch (Exception e) {
                emitter.completeWithError(e);
            }
        });
        return emitter;
    }
}
