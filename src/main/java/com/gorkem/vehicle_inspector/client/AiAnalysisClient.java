package com.gorkem.vehicle_inspector.client;

import com.gorkem.vehicle_inspector.dto.response.AiAnalysisResponse;
import com.gorkem.vehicle_inspector.dto.response.ImageQualityResponse;
import com.gorkem.vehicle_inspector.exception.DamageAnalysisUnavailableException;
import org.springframework.stereotype.Component;

import java.nio.file.Path;

/** Model-independent boundary. No damage analysis provider is currently installed. */
@Component
public class AiAnalysisClient {
    public void requireAvailable() {
        throw new DamageAnalysisUnavailableException();
    }

    public AiAnalysisResponse analyze(Path imagePath) {
        throw new DamageAnalysisUnavailableException();
    }

    public AiAnalysisResponse analyzeSingleImage(Path imagePath, String vehicleRegion) {
        throw new DamageAnalysisUnavailableException();
    }

    public AiAnalysisResponse analyze(Path imagePath, Path contextImagePath) {
        throw new DamageAnalysisUnavailableException();
    }

    public AiAnalysisResponse analyze(Path imagePath, Path contextImagePath, String vehicleRegion) {
        throw new DamageAnalysisUnavailableException();
    }

    public ImageQualityResponse validateImage(Path imagePath) {
        throw new DamageAnalysisUnavailableException();
    }

    public ImageQualityResponse validateImage(Path imagePath, String purpose) {
        throw new DamageAnalysisUnavailableException();
    }
}
