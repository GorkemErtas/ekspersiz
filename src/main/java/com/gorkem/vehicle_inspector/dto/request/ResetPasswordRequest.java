package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class ResetPasswordRequest {

    @NotBlank(message = "E-posta adresi zorunludur.")
    @Email(message = "Geçerli bir e-posta adresi girin.")
    private String email;

    @NotBlank(message = "Doğrulama kodu zorunludur.")
    @Size(min = 6, max = 6, message = "Doğrulama kodu 6 haneli olmalıdır.")
    private String code;

    @NotBlank(message = "Yeni şifre zorunludur.")
    @Size(min = 8, max = 100, message = "Şifre en az 8 karakter olmalıdır.")
    private String newPassword;

    @NotBlank(message = "Şifre tekrarı zorunludur.")
    private String confirmNewPassword;

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

    public String getNewPassword() {
        return newPassword;
    }

    public void setNewPassword(String newPassword) {
        this.newPassword = newPassword;
    }

    public String getConfirmNewPassword() {
        return confirmNewPassword;
    }

    public void setConfirmNewPassword(String confirmNewPassword) {
        this.confirmNewPassword = confirmNewPassword;
    }
}