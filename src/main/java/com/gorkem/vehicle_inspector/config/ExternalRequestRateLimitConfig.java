package com.gorkem.vehicle_inspector.config;

import com.gorkem.vehicle_inspector.security.RequestRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import static com.gorkem.vehicle_inspector.security.RequestRateLimiter.Action.*;

/** Abuse limits complement credit accounting; polling and image reads stay unchanged. */
@Configuration
public class ExternalRequestRateLimitConfig implements WebMvcConfigurer {
    private final RequestRateLimiter limiter;

    public ExternalRequestRateLimitConfig(RequestRateLimiter limiter) { this.limiter = limiter; }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
                if (request.getUserPrincipal() == null) return true; // Security owns authentication.
                // Use the resolved route, so alternate valid Long representations
                // such as +1 cannot bypass a numeric-path regular expression.
                String path = String.valueOf(request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE));
                String method = request.getMethod();
                RequestRateLimiter.Action action = null;
                if (method.equals("POST")) {
                    if (path.equals("/api/v1/ai-assistant/chat")) action = AI_CHAT;
                    else if (path.equals("/api/v1/billing/sync")) action = BILLING_SYNC;
                    else if (path.equals("/api/v1/inspections/{inspectionId}/analyze")
                            || path.equals("/api/v1/inspections/{inspectionId}/report")) action = INSPECTION_AI;
                    else if (path.equals("/api/v1/inspections/{inspectionId}/image-quality")
                            || path.equals("/api/v1/inspections/{inspectionId}/context-image-quality")) action = IMAGE_QUALITY;
                    else if (path.equals("/api/v1/inspections/{inspectionId}/image")
                            || path.equals("/api/v1/inspections/{inspectionId}/context-image")) action = PHOTO_UPLOAD;
                } else if (method.equals("GET") && path.equals("/api/v1/inspections/{inspectionId}/nearby-services")) {
                    action = NEARBY_SEARCH;
                }
                if (action != null) limiter.check(action, request.getUserPrincipal().getName());
                return true;
            }
        }).addPathPatterns("/api/v1/**");
    }
}
