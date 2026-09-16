package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.security.CustomUserDetailsService;
import com.gorkem.vehicle_inspector.security.JwtAuthenticationFilter;
import com.gorkem.vehicle_inspector.security.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class JwtAuthenticationFilterTest {

    @Test
    void revenueCatAuthorizationShouldBypassJwtParsing() throws Exception {
        JwtService jwtService = mock(JwtService.class);
        CustomUserDetailsService userDetailsService =
                mock(CustomUserDetailsService.class);
        JwtAuthenticationFilter filter = new JwtAuthenticationFilter(
                jwtService,
                userDetailsService
        );
        MockHttpServletRequest request = new MockHttpServletRequest(
                "POST",
                "/api/v1/billing/revenuecat/webhook"
        );
        request.setServletPath("/api/v1/billing/revenuecat/webhook");
        request.addHeader("Authorization", "Bearer webhook-secret");

        filter.doFilter(
                request,
                new MockHttpServletResponse(),
                (ignoredRequest, ignoredResponse) -> {
                }
        );

        verifyNoInteractions(jwtService, userDetailsService);
    }
}
