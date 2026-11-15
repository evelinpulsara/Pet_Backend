package com.pettracker.backend.ai;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

/** Datos que la app envía a los endpoints de IA (validados al llegar). */
public final class AiDtos {
    private AiDtos() {}

    /** Mascota que salió de su zona (o que el dueño reportó como perdida). */
    public record LostPetRequest(
            @NotBlank @Size(max = 60) String petName,
            @Size(max = 40) String species,
            @Size(max = 60) String breed,
            @Min(0) @Max(60) int age,
            @Size(max = 60) String ownerName,
            @Size(max = 60) String zoneName,
            @DecimalMin("0") @DecimalMax("100000") double distanceOutsideMeters,
            @Min(0) @Max(100) int batteryLevel,
            @Pattern(regexp = "^\\d{2}:\\d{2}$") String time,
            @Pattern(regexp = "^(es|en)$") String locale) {}

    public record LostPetResponse(String ownerAlert, String contactMessage, boolean fromAi) {}

    public record PosterResponse(String headline, String description, boolean fromAi) {}

    /** Datos del día para el resumen. */
    public record DaySummaryRequest(
            @NotBlank @Size(max = 60) String petName,
            @Size(max = 40) String species,
            @DecimalMin("0") double distanceMeters,
            @DecimalMin("0") double goalMeters,
            @Min(0) int activeMinutes,
            @Min(0) int walks,
            @Min(0) int walkMinutes,
            @Min(0) int alertsToday,
            @Min(0) int minutesOutside,
            @Size(max = 20) List<@Size(max = 60) String> placesVisited,
            @Size(max = 20) List<@Size(max = 200) String> unusual,
            @Pattern(regexp = "^(es|en)$") String locale) {}

    public record DaySummaryResponse(String summary, boolean fromAi) {}
}
