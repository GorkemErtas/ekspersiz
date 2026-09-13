package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public class VerifyEmailRequest {

    @NotBlank(message = "E-posta adresi boş bırakılamaz.")
    @Email(message = "Geçerli bir e-posta adresi girilmelidir.")
    private String email;

    @NotBlank(message = "Doğrulama kodu boş bırakılamaz.")
    @Pattern(
            regexp = "\\d{6}",
            message = "Doğrulama kodu 6 haneli olmalıdır."
    )
    private String code;

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getCode() {
        return code;
    }

    public void setCode(String code) {
        this.code = code;
    }
}
