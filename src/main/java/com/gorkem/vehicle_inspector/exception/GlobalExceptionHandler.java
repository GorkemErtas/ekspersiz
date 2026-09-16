package com.gorkem.vehicle_inspector.exception;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.security.core.AuthenticationException;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log =
            LoggerFactory.getLogger(
                    GlobalExceptionHandler.class
            );

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiErrorResponse>
    handleValidationException(
            MethodArgumentNotValidException exception
    ) {
        Map<String, String> validationErrors =
                new LinkedHashMap<>();

        exception.getBindingResult()
                .getFieldErrors()
                .forEach(fieldError ->
                        validationErrors.put(
                                fieldError.getField(),
                                fieldError.getDefaultMessage()
                        )
                );

        return buildResponse(
                HttpStatus.BAD_REQUEST,
                "Gönderilen bilgiler geçersiz.",
                validationErrors
        );
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ApiErrorResponse>
    handleResourceNotFoundException(
            ResourceNotFoundException exception
    ) {
        return buildResponse(
                HttpStatus.NOT_FOUND,
                exception.getMessage()
        );
    }

    @ExceptionHandler(DuplicateResourceException.class)
    public ResponseEntity<ApiErrorResponse>
    handleDuplicateResourceException(
            DuplicateResourceException exception
    ) {
        return buildResponse(
                HttpStatus.CONFLICT,
                exception.getMessage()
        );
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ApiErrorResponse>
    handleAuthenticationException(
            AuthenticationException exception
    ) {
        return buildResponse(
                HttpStatus.UNAUTHORIZED,
                "E-posta veya şifre hatalı."
        );
    }

    @ExceptionHandler(FileStorageException.class)
    public ResponseEntity<ApiErrorResponse>
    handleFileStorageException(
            FileStorageException exception
    ) {
        return buildResponse(
                HttpStatus.BAD_REQUEST,
                exception.getMessage()
        );
    }

    @ExceptionHandler(AiServiceException.class)
    public ResponseEntity<ApiErrorResponse>
    handleAiServiceException(
            AiServiceException exception
    ) {
        log.error(
                "AI service error",
                exception
        );

        return buildResponse(
                HttpStatus.BAD_GATEWAY,
                exception.getMessage()
        );
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<ApiErrorResponse>
    handleMaxUploadSizeExceededException(
            MaxUploadSizeExceededException exception
    ) {
        return buildResponse(
                HttpStatus.PAYLOAD_TOO_LARGE,
                "Yüklenen fotoğraf izin verilen "
                        + "maksimum boyutu aşıyor."
        );
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiErrorResponse>
    handleHttpMessageNotReadableException(
            HttpMessageNotReadableException exception
    ) {
        return buildResponse(
                HttpStatus.BAD_REQUEST,
                "İstek gövdesi okunamadı veya "
                        + "geçersiz JSON formatında."
        );
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<ApiErrorResponse>
    handleIllegalArgumentException(
            IllegalArgumentException exception
    ) {
        return buildResponse(
                HttpStatus.BAD_REQUEST,
                exception.getMessage()
        );
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<ApiErrorResponse>
    handleIllegalStateException(
            IllegalStateException exception
    ) {
        return buildResponse(
                HttpStatus.CONFLICT,
                exception.getMessage()
        );
    }

    @ExceptionHandler(BillingConfigurationException.class)
    public ResponseEntity<ApiErrorResponse>
    handleBillingConfigurationException(
            BillingConfigurationException exception
    ) {
        return buildResponse(
                HttpStatus.SERVICE_UNAVAILABLE,
                exception.getMessage()
        );
    }

    @ExceptionHandler(BillingProviderException.class)
    public ResponseEntity<ApiErrorResponse>
    handleBillingProviderException(
            BillingProviderException exception
    ) {
        log.error("Billing provider error", exception);

        return buildResponse(
                HttpStatus.BAD_GATEWAY,
                exception.getMessage()
        );
    }

    @ExceptionHandler(InvalidBillingWebhookException.class)
    public ResponseEntity<ApiErrorResponse>
    handleInvalidBillingWebhookException(
            InvalidBillingWebhookException exception
    ) {
        return buildResponse(
                HttpStatus.UNAUTHORIZED,
                exception.getMessage()
        );
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiErrorResponse>
    handleUnexpectedException(
            Exception exception
    ) {
        log.error(
                "Unexpected server error",
                exception
        );

        return buildResponse(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Beklenmeyen bir sunucu hatası oluştu."
        );
    }

    private ResponseEntity<ApiErrorResponse> buildResponse(
            HttpStatus status,
            String message
    ) {
        return buildResponse(
                status,
                message,
                Map.of()
        );
    }

    private ResponseEntity<ApiErrorResponse> buildResponse(
            HttpStatus status,
            String message,
            Map<String, String> errors
    ) {
        ApiErrorResponse response =
                new ApiErrorResponse(
                        LocalDateTime.now(),
                        status.value(),
                        message,
                        errors
                );

        return ResponseEntity
                .status(status)
                .body(response);
    }
}
