package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.client.AiAnalysisClient;
import com.gorkem.vehicle_inspector.exception.DamageAnalysisUnavailableException;
import com.gorkem.vehicle_inspector.exception.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.function.Executable;

import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class AiAnalysisClientTest {
    @Test
    void allImageOperationsFailWithoutReadingFilesOrCallingExternalServices() {
        var client = new AiAnalysisClient();
        var missing = Path.of("nonexistent-photo.jpg");
        List<Executable> operations = List.of(
                client::requireAvailable,
                () -> client.analyze(missing),
                () -> client.analyzeSingleImage(missing, "FRONT"),
                () -> client.analyze(missing, missing),
                () -> client.analyze(missing, missing, "REAR"),
                () -> client.validateImage(missing),
                () -> client.validateImage(missing, "damage"));
        for (var operation : operations) {
            assertThrows(DamageAnalysisUnavailableException.class, operation);
        }
    }

    @Test
    void unavailableIsReportedAs503WithAnActionableMessage() {
        var response = new GlobalExceptionHandler().handleDamageAnalysisUnavailable(
                new DamageAnalysisUnavailableException());
        assertEquals(503, response.getStatusCode().value());
        assertNotNull(response.getBody());
    }
}
