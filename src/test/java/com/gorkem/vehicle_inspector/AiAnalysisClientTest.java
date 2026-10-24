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
    void approvedProviderReadinessThenSinglePhotoContractIsUsed() throws Exception {
        var template=new org.springframework.web.client.RestTemplate();
        var server=org.springframework.test.web.client.MockRestServiceServer.createServer(template);
        var client=new AiAnalysisClient(template);
        org.springframework.test.util.ReflectionTestUtils.setField(client,"enabled",true);
        org.springframework.test.util.ReflectionTestUtils.setField(client,"baseUrl","https://vision.test");
        org.springframework.test.util.ReflectionTestUtils.setField(client,"serviceApiKey","test-service-key");
        var image=temporary.resolve("car.png");java.nio.file.Files.write(image,new byte[]{1,2,3});
        server.expect(org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo("https://vision.test/api/v1/vision/readiness"))
                .andExpect(org.springframework.test.web.client.match.MockRestRequestMatchers.header("X-AI-Service-Key","test-service-key"))
                .andRespond(org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess(
                        "{\"status\":\"READY\",\"schemaVersion\":\"hitl-v1\"}",org.springframework.http.MediaType.APPLICATION_JSON));
        server.expect(org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo("https://vision.test/api/v1/analyze"))
                .andExpect(org.springframework.test.web.client.match.MockRestRequestMatchers.method(org.springframework.http.HttpMethod.POST))
                .andExpect(org.springframework.test.web.client.match.MockRestRequestMatchers.content().contentTypeCompatibleWith(org.springframework.http.MediaType.MULTIPART_FORM_DATA))
                .andRespond(org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess(
                        new com.fasterxml.jackson.databind.ObjectMapper().writeValueAsString(new HitlAnalysisValidatorTest().response()),
                        org.springframework.http.MediaType.APPLICATION_JSON));
        var result=client.analyzeSingleImage(image,"FRONT");
        assertEquals("hitl-v1",result.getSchemaVersion());
        assertEquals("Scratch",result.getDetections().getFirst().getLabel());
        server.verify();
    }
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
