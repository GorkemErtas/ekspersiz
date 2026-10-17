package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.client.AiAnalysisClient;
import com.gorkem.vehicle_inspector.entity.DamageSeverity;
import com.gorkem.vehicle_inspector.exception.AiServiceException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestTemplate;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;

class AiAnalysisClientTest {
    @TempDir Path directory;
    private Path image;
    private Path context;
    private MockRestServiceServer server;
    private AiAnalysisClient client;

    @BeforeEach
    void setUp() throws Exception {
        image = Files.write(directory.resolve("damage.jpg"), new byte[]{1, 2, 3});
        context = Files.write(directory.resolve("context.png"), new byte[]{4, 5, 6});
        RestTemplate template = new RestTemplate();
        server = MockRestServiceServer.createServer(template);
        client = new AiAnalysisClient(template, "https://ai.test/");
    }

    @Test
    void singlePhotoMultipartContainsRegionAndNoContextImage() {
        server.expect(requestTo("https://ai.test/api/v1/analyze"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(content().string(allOf(
                        containsString("name=\"image\""),
                        containsString("name=\"vehicle_region\""), containsString("REAR"),
                        not(containsString("context_image")))))
                .andRespond(withSuccess("{\"damageSeverity\":\"NONE\"}", MediaType.APPLICATION_JSON));

        assertEquals(DamageSeverity.NONE, client.analyzeSingleImage(image, "REAR").getDamageSeverity());
        server.verify();
    }

    @Test
    void oldSinglePhotoMethodStillWorksWithoutARegion() {
        server.expect(requestTo("https://ai.test/api/v1/analyze"))
                .andExpect(content().string(allOf(not(containsString("vehicle_region")), not(containsString("context_image")))))
                .andRespond(withSuccess("{\"damageSeverity\":\"MINOR\"}", MediaType.APPLICATION_JSON));
        assertEquals(DamageSeverity.MINOR, client.analyze(image).getDamageSeverity());
        server.verify();
    }

    @Test
    void legacyPairMultipartKeepsBothFilesAndRegion() {
        server.expect(requestTo("https://ai.test/api/v1/analyze"))
                .andExpect(content().string(allOf(
                        containsString("name=\"image\""), containsString("name=\"context_image\""),
                        containsString("name=\"vehicle_region\""), containsString("FRONT"))))
                .andRespond(withSuccess("{\"damageSeverity\":\"MINOR\"}", MediaType.APPLICATION_JSON));
        assertEquals(DamageSeverity.MINOR, client.analyze(image, context, "FRONT").getDamageSeverity());
        server.verify();
    }

    @Test
    void singlePhotoQualityValidationKeepsDamagePurpose() {
        server.expect(requestTo("https://ai.test/api/v1/validate-image?purpose=damage"))
                .andRespond(withSuccess("{\"suitable\":false,\"code\":\"TOO_DARK\",\"message\":\"Retake\"}", MediaType.APPLICATION_JSON));
        assertFalse(client.validateImage(image, "damage").suitable());
        server.verify();
    }

    @Test
    void unsuitableAnalysisReturnsActionableGuidance() {
        server.expect(requestTo("https://ai.test/api/v1/analyze"))
                .andRespond(withStatus(HttpStatus.BAD_REQUEST).contentType(MediaType.APPLICATION_JSON)
                        .body("{\"detail\":\"Unrecognizable vehicle\"}"));
        AiServiceException error = assertThrows(AiServiceException.class,
                () -> client.analyzeSingleImage(image, "FRONT"));
        assertTrue(error.getMessage().contains("çevresindeki araç parçasını"));
        server.verify();
    }

    @Test
    void missingFileFailsBeforeAnHttpRequest() {
        assertThrows(AiServiceException.class,
                () -> client.analyzeSingleImage(directory.resolve("missing.jpg"), "FRONT"));
        server.verify();
    }
}
