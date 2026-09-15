package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record CreateBusinessInvitationRequest(

        @NotBlank(message = "E-posta adresi zorunludur.")
        @Email(message = "Geçerli bir e-posta adresi girin.")
        String email

) {
}