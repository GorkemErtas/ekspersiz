package com.gorkem.vehicle_inspector.exception;

public class UnsuitableInspectionImageException extends RuntimeException {
    private static final java.util.Set<String> SAFE_CODES = java.util.Set.of(
            "IMAGE_SIZE_INVALID", "IMAGE_FORMAT_INVALID", "IMAGE_ANIMATED",
            "IMAGE_RESOLUTION_EXCEEDED", "IMAGE_RESOLUTION_TOO_LOW",
            "IMAGE_DETAIL_INSUFFICIENT", "IMAGE_DECODE_FAILED");
    private final String code;
    private final String imageRole;

    public UnsuitableInspectionImageException(String message) {
        this(message, "INVALID_IMAGE", false);
    }

    public UnsuitableInspectionImageException(String message, String code, boolean contextImage) {
        super((contextImage ? "Genel görünüm fotoğrafı: " : "Yakın detay fotoğrafı: ") + message);
        this.code = SAFE_CODES.contains(code == null ? "" : code) ? code : "INVALID_IMAGE";
        this.imageRole = contextImage ? "context" : "damage";
    }

    public String getCode() { return code; }
    public String getImageRole() { return imageRole; }
}
