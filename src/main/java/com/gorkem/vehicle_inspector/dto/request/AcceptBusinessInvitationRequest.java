package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record AcceptBusinessInvitationRequest(

        @NotBlank(message = "Davet kodu zorunludur.")
        @Pattern(
                regexp = "\\d{6}",
                message = "Davet kodu 6 haneli olmalıdır."
        )
        String code

) {
}