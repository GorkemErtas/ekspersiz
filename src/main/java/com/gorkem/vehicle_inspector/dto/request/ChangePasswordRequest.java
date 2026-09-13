package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class ChangePasswordRequest {

    @NotBlank(message = "Mevcut şifre boş bırakılamaz.")
    private String currentPassword;

    @NotBlank(message = "Yeni şifre boş bırakılamaz.")
    @Size(
            min = 8,
            max = 72,
            message = "Yeni şifre 8 ile 72 karakter arasında olmalıdır."
    )
    private String newPassword;

    @NotBlank(message = "Yeni şifre tekrarı boş bırakılamaz.")
    private String confirmNewPassword;

    public String getCurrentPassword() {
        return currentPassword;
    }

    public void setCurrentPassword(String currentPassword) {
        this.currentPassword = currentPassword;
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
