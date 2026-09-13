package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public class ResendVerificationRequest {

    @NotBlank(message = "E-posta adresi boş bırakılamaz.")
    @Email(message = "Geçerli bir e-posta adresi girilmelidir.")
    private String email;

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }
}
