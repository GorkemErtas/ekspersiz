package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateBusinessAccountRequest(

        @NotBlank(message = "Şirket adı zorunludur.")
        @Size(
                max = 150,
                message = "Şirket adı en fazla 150 karakter olabilir."
        )
        String companyName

) {
}