package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.security.SensitiveRequestBodyFilter;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.*;
import java.util.concurrent.atomic.AtomicBoolean;
import static org.junit.jupiter.api.Assertions.*;

class SensitiveRequestBodyFilterTest {
    @Test void permitsExistingHistoryWithUnicodeEscapes() throws Exception {
        var request = new MockHttpServletRequest("POST", "/api/v1/ai-assistant/chat");
        request.setServletPath("/api/v1/ai-assistant/chat");
        String content = "\\u00e7".repeat(2000);
        String history = java.util.stream.IntStream.range(0, 6)
                .mapToObj(i -> "{\"role\":\"user\",\"content\":\"" + content + "\"}")
                .collect(java.util.stream.Collectors.joining(","));
        byte[] body = ("{\"question\":\"" + content + "\",\"history\":[" + history + "]}")
                .getBytes(java.nio.charset.StandardCharsets.UTF_8);
        request.setContent(body);
        AtomicBoolean invoked = new AtomicBoolean();
        new SensitiveRequestBodyFilter().doFilter(request, new MockHttpServletResponse(), (req, res) -> {
            assertArrayEquals(body, req.getInputStream().readAllBytes());
            invoked.set(true);
        });
        assertTrue(invoked.get());
    }

    @Test void rejectsOversizeChunkedJsonBeforeController() throws Exception {
        var request = new MockHttpServletRequest("POST", "/api/v1/auth/login") {
            @Override public long getContentLengthLong() { return -1; }
        };
        request.setServletPath("/api/v1/auth/login");
        request.setContent(new byte[65 * 1024]);
        var response = new MockHttpServletResponse();
        AtomicBoolean invoked = new AtomicBoolean();
        new SensitiveRequestBodyFilter().doFilter(request, response, (req, res) -> invoked.set(true));
        assertEquals(413, response.getStatus()); assertFalse(invoked.get());
    }

    @Test void preservesExactWebhookBytesForSignatureVerification() throws Exception {
        var request = new MockHttpServletRequest("POST", "/api/v1/billing/revenuecat/webhook");
        request.setServletPath("/api/v1/billing/revenuecat/webhook");
        byte[] body = "{ \"event\" : {\"id\":\"örnek\"} }\n".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        request.setContent(body);
        new SensitiveRequestBodyFilter().doFilter(request, new MockHttpServletResponse(),
                (req, res) -> assertArrayEquals(body, req.getInputStream().readAllBytes()));
    }
}
