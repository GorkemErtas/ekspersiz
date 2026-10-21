package com.gorkem.vehicle_inspector.security;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.*;
import java.nio.charset.StandardCharsets;

/** Bound sensitive JSON bodies before Jackson, including requests without Content-Length. */
@Component
@Order(-90) // after Spring Security's authentication filter chain
public class SensitiveRequestBodyFilter extends OncePerRequestFilter {
    @Override protected boolean shouldNotFilter(HttpServletRequest request) {
        if (!"POST".equals(request.getMethod())) return true;
        String path = request.getServletPath();
        return !(path.startsWith("/api/v1/auth/")
                || path.equals("/api/v1/ai-assistant/chat")
                || path.equals("/api/v1/billing/revenuecat/webhook")
                || path.startsWith("/api/v1/credits/welcome/"));
    }

    @Override protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                              FilterChain chain) throws ServletException, IOException {
        int limit = request.getServletPath().endsWith("/webhook") ? 256 * 1024 : 64 * 1024;
        if (request.getContentLengthLong() > limit) { tooLarge(response); return; }
        byte[] body = request.getInputStream().readNBytes(limit + 1);
        if (body.length > limit) { tooLarge(response); return; }
        chain.doFilter(new HttpServletRequestWrapper(request) {
            @Override public ServletInputStream getInputStream() {
                ByteArrayInputStream input = new ByteArrayInputStream(body);
                return new ServletInputStream() {
                    @Override public int read() { return input.read(); }
                    @Override public int read(byte[] bytes, int offset, int length) { return input.read(bytes, offset, length); }
                    @Override public boolean isFinished() { return input.available() == 0; }
                    @Override public boolean isReady() { return true; }
                    @Override public void setReadListener(ReadListener listener) {
                        throw new IllegalStateException("Only synchronous JSON request bodies are supported.");
                    }
                };
            }
            @Override public BufferedReader getReader() {
                return new BufferedReader(new InputStreamReader(getInputStream(), StandardCharsets.UTF_8));
            }
        }, response);
    }

    private void tooLarge(HttpServletResponse response) throws IOException {
        response.setStatus(413);
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write("{\"status\":413,\"message\":\"İstek gövdesi çok büyük.\"}");
    }
}
