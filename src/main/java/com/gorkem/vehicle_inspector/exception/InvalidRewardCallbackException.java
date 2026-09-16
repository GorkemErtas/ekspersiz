package com.gorkem.vehicle_inspector.exception;

public class InvalidRewardCallbackException extends RuntimeException {
    public InvalidRewardCallbackException(String message) {
        super(message);
    }

    public InvalidRewardCallbackException(String message, Throwable cause) {
        super(message, cause);
    }
}
