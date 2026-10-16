package com.gorkem.vehicle_inspector.exception;

/** Free monthly AI Assistant quota exhausted; show subscription plans. */
public class FreeAssistantQuotaExceededException extends RuntimeException {
    public FreeAssistantQuotaExceededException(String message) {
        super(message);
    }
}
