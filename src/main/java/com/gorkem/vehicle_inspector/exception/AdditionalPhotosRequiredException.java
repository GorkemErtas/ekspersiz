package com.gorkem.vehicle_inspector.exception;

import com.gorkem.vehicle_inspector.dto.response.AiAnalysisResponse;

public class AdditionalPhotosRequiredException extends AiServiceException {
    private final AiAnalysisResponse analysis;
    public AdditionalPhotosRequiredException(AiAnalysisResponse analysis) {
        super(analysis.getAdditionalPhotoGuidance());
        this.analysis = analysis;
    }
    public AiAnalysisResponse getAnalysis() { return analysis; }
}
