package com.gorkem.vehicle_inspector.exception;

public class DamageAnalysisUnavailableException extends RuntimeException {
    public DamageAnalysisUnavailableException() {
        super("Hasar analizi geçici olarak kullanılamıyor. Mevcut analiz ve raporlarınıza erişebilirsiniz.");
    }
}
