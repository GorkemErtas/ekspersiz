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
    @org.junit.jupiter.api.io.TempDir Path temporary;

    @Test
    void http200WithUnsuitableBodyRemainsARejection() throws Exception {
        var template = new org.springframework.web.client.RestTemplate();
        var server = org.springframework.test.web.client.MockRestServiceServer.createServer(template);
        var client = new AiAnalysisClient(template);
        org.springframework.test.util.ReflectionTestUtils.setField(client, "baseUrl", "https://vision.test");
        var image = temporary.resolve("photo.jpg");
        java.nio.file.Files.write(image, new byte[]{1, 2, 3});
        server.expect(org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo("https://vision.test/api/v1/vision/readiness"))
                .andRespond(org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess(
                        "{\"status\":\"READY\",\"schemaVersion\":\"gemini-vision-v1\"}", org.springframework.http.MediaType.APPLICATION_JSON));
        server.expect(org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo("https://vision.test/api/v1/validate-image"))
                .andRespond(org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess(
                        "{\"suitable\":false,\"code\":\"IMAGE_RESOLUTION_EXCEEDED\",\"message\":\"Fotoğraf 24 MP sınırını aşıyor.\"}",
                        org.springframework.http.MediaType.APPLICATION_JSON));
        var result = client.validateImage(image);
        assertFalse(result.suitable());
        assertEquals("IMAGE_RESOLUTION_EXCEEDED", result.code());
        server.verify();
    }

    @Test
    void unknownRejectionCodesCannotLeakUntrustedTextToLogs() {
        var error = new com.gorkem.vehicle_inspector.exception.UnsuitableInspectionImageException(
                "Fotoğraf uygun değil.", "private-filename.jpg\nforged-log-entry", false);
        assertEquals("INVALID_IMAGE", error.getCode());
    }

    @Test
    void configuredProviderReceivesBothPhotosInOneRequest() throws Exception {
        var template=new org.springframework.web.client.RestTemplate();
        var server=org.springframework.test.web.client.MockRestServiceServer.createServer(template);
        var client=new AiAnalysisClient(template);
        org.springframework.test.util.ReflectionTestUtils.setField(client,"enabled",true);
        org.springframework.test.util.ReflectionTestUtils.setField(client,"baseUrl","https://vision.test");
        org.springframework.test.util.ReflectionTestUtils.setField(client,"serviceApiKey","test-service-key");
        var image=temporary.resolve("car.png");java.nio.file.Files.write(image,new byte[]{1,2,3});
        var overview=temporary.resolve("overview.png");java.nio.file.Files.write(overview,new byte[]{4,5,6});
        server.expect(org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo("https://vision.test/api/v1/vision/readiness"))
                .andExpect(org.springframework.test.web.client.match.MockRestRequestMatchers.header("X-AI-Service-Key","test-service-key"))
                .andRespond(org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess(
                        "{\"status\":\"READY\",\"schemaVersion\":\"gemini-vision-v1\"}",org.springframework.http.MediaType.APPLICATION_JSON));
        server.expect(org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo("https://vision.test/api/v1/analyze"))
                .andExpect(org.springframework.test.web.client.match.MockRestRequestMatchers.method(org.springframework.http.HttpMethod.POST))
                .andExpect(org.springframework.test.web.client.match.MockRestRequestMatchers.content().contentTypeCompatibleWith(org.springframework.http.MediaType.MULTIPART_FORM_DATA))
                .andExpect(org.springframework.test.web.client.match.MockRestRequestMatchers.content().string(org.hamcrest.Matchers.containsString("name=\"image\"")))
                .andExpect(org.springframework.test.web.client.match.MockRestRequestMatchers.content().string(org.hamcrest.Matchers.containsString("name=\"context_image\"")))
                .andRespond(org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess(
                        java.nio.file.Files.readString(Path.of("contracts/gemini-vision-v1.example.json")),
                        org.springframework.http.MediaType.APPLICATION_JSON));
        var result=client.analyze(image,overview,"FRONT");
        assertEquals("gemini-vision-v1",result.getSchemaVersion());
        assertEquals("SCRATCH",result.getVisualFindings().getFirst().damageType().name());
        assertTrue(result.getVisualFindings().getFirst().description().contains("Kapı"));
        server.verify();
    }
    @Test
    void allImageOperationsFailWithoutReadingFilesOrCallingExternalServices() {
        var client = new AiAnalysisClient();
        var missing = Path.of("nonexistent-photo.jpg");
        List<Executable> operations = List.of(
                client::requireAvailable,
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
