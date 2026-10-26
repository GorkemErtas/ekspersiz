package com.gorkem.vehicle_inspector.exception;

public class WorkspaceAccessDeniedException extends RuntimeException {
    public WorkspaceAccessDeniedException() {
        super("Seçilen çalışma alanına erişiminiz yok. Çalışma alanınızı yenileyin.");
    }
}
