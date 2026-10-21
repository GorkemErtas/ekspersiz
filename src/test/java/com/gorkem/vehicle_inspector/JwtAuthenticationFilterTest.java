package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.security.CustomUserDetailsService;
import com.gorkem.vehicle_inspector.security.JwtAuthenticationFilter;
import com.gorkem.vehicle_inspector.security.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import java.util.concurrent.atomic.AtomicBoolean;

class JwtAuthenticationFilterTest {

    @Test
    void deletedAccountTokenContinuesUnauthenticatedInsteadOfThrowing() throws Exception {
        SecurityContextHolder.clearContext();
        JwtService jwt = mock(JwtService.class);
        CustomUserDetailsService users = mock(CustomUserDetailsService.class);
        when(jwt.extractEmail("old-token")).thenReturn("deleted@example.com");
        when(users.loadUserByUsername("deleted@example.com"))
                .thenThrow(new UsernameNotFoundException("deleted"));
        var request = new MockHttpServletRequest("GET", "/api/v1/auth/me");
        request.addHeader("Authorization", "Bearer old-token");
        AtomicBoolean continued = new AtomicBoolean();
        new JwtAuthenticationFilter(jwt, users).doFilter(request, new MockHttpServletResponse(),
                (req, res) -> continued.set(true));
        assertTrue(continued.get());
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }

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
