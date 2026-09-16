package com.gorkem.vehicle_inspector.dto.request;

import com.gorkem.vehicle_inspector.entity.DevicePlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record DeviceTokenRequest(
        @NotBlank @Size(max = 512) String token,
        @NotNull DevicePlatform platform
) {
}
