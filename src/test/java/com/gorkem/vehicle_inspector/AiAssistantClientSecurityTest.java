package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.client.AiAssistantClient;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestTemplate;
import java.util.List;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;

class AiAssistantClientSecurityTest {
    @Test void attachesServiceCredentialToPlannerRequest() {
        RestTemplate http = new RestTemplate();
        var server = MockRestServiceServer.createServer(http);
        var client = new AiAssistantClient(http, "https://ai.test");
        ReflectionTestUtils.setField(client, "serviceApiKey", "test-service-key");
        server.expect(requestTo("https://ai.test/api/v1/assistant/plan"))
                .andExpect(header("X-AI-Service-Key", "test-service-key"))
                .andRespond(withSuccess("""
                        {"intent":"GENERAL","in_scope":true,"use_rag":false,"knowledge_source":"PUBLIC_WEB",
                        "automotive_relevance":1.0,"assistant_capability":1.0,"evidence_score":1.0,
                        "evidence_sufficient":true,"clarification_needed":false,"context":[]}
                        """, MediaType.APPLICATION_JSON));
        client.plan("question", List.of(), null);
        server.verify();
    }
}
