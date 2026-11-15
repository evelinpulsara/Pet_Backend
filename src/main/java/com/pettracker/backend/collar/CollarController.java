package com.pettracker.backend.collar;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pettracker.backend.config.AppProperties;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * Entrada del COLLAR GPS (por ejemplo un Arduino con Wi-Fi o GSM).
 *
 *   POST /api/collar/location
 *   {"deviceUid":"TRK-1001","deviceKey":"clave-secreta-123","lat":1.2136,"lon":-77.2811,"accuracy":5,"battery":87}
 *
 * Valida los datos y los guarda en Supabase con la función report_location,
 * que comprueba el código y la clave del collar. La app se entera al instante
 * por WebSocket (Supabase Realtime).
 */
@RestController
@RequestMapping("/api/collar")
public class CollarController {

    /** Lo que envía el collar (validado al llegar). */
    public record LocationReport(
            @NotBlank @Size(max = 100) String deviceUid,
            @NotBlank @Size(min = 12, max = 200) String deviceKey,
            @NotNull @DecimalMin("-90") @DecimalMax("90") Double lat,
            @NotNull @DecimalMin("-180") @DecimalMax("180") Double lon,
            @DecimalMin("0") @DecimalMax("10000") Double accuracy,
            @Min(0) @Max(100) Integer battery,
            @DecimalMin("0") @DecimalMax("400") Double speed) {}

    private final AppProperties props;
    private final ObjectMapper json;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

    public CollarController(AppProperties props, ObjectMapper json) {
        this.props = props;
        this.json = json;
    }

    @PostMapping("/location")
    public Map<String, Object> report(@Valid @RequestBody LocationReport r) throws Exception {
        if (r.lat() == 0 && r.lon() == 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Ubicación (0,0): el GPS aún no tiene señal");
        }
        var params = new HashMap<String, Object>();
        params.put("p_device_uid", r.deviceUid());
        params.put("p_device_key", r.deviceKey());
        params.put("p_lat", r.lat());
        params.put("p_lon", r.lon());
        if (r.accuracy() != null) params.put("p_accuracy", r.accuracy());
        if (r.battery() != null) params.put("p_battery", r.battery());
        if (r.speed() != null) params.put("p_speed", r.speed());

        var req = HttpRequest.newBuilder(URI.create(props.supabaseUrl() + "/rest/v1/rpc/report_location"))
                .timeout(Duration.ofSeconds(15))
                .header("apikey", props.supabaseKey())
                .header("Content-Type", "application/json")
                .header("Content-Profile", "pettracker")
                .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(params)))
                .build();
        var res = http.send(req, HttpResponse.BodyHandlers.ofString());
        if (res.statusCode() == 200) {
            return Map.of("saved", true, "id", Long.parseLong(res.body().trim()));
        }
        if (res.body().contains("no autorizado")) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Collar no autorizado (código o clave incorrectos)");
        }
        throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "No se pudo guardar en la base de datos");
    }
}
