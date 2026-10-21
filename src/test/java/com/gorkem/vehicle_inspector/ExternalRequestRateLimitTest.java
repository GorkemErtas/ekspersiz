package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.config.ExternalRequestRateLimitConfig;
import com.gorkem.vehicle_inspector.controller.DamageInspectionController;
import com.gorkem.vehicle_inspector.exception.GlobalExceptionHandler;
import com.gorkem.vehicle_inspector.exception.RateLimitExceededException;
import com.gorkem.vehicle_inspector.security.RequestRateLimiter;
import com.gorkem.vehicle_inspector.service.DamageInspectionService;
import com.gorkem.vehicle_inspector.service.NearbyServiceService;
import org.junit.jupiter.api.*;
import org.springframework.context.annotation.*;
import org.springframework.mock.web.MockServletContext;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.support.AnnotationConfigWebApplicationContext;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;

import static com.gorkem.vehicle_inspector.security.RequestRateLimiter.Action.IMAGE_QUALITY;
import static com.gorkem.vehicle_inspector.security.RequestRateLimiter.Action.INSPECTION_AI;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class ExternalRequestRateLimitTest {
    private AnnotationConfigWebApplicationContext context;
    private MockMvc mvc;
    private RequestRateLimiter limiter;
    private final UsernamePasswordAuthenticationToken user =
            new UsernamePasswordAuthenticationToken("owner@example.com", null, java.util.List.of());

    @BeforeEach void setup() {
        context = new AnnotationConfigWebApplicationContext();
        context.setServletContext(new MockServletContext());
        context.register(Config.class);
        context.refresh();
        limiter = context.getBean(RequestRateLimiter.class);
        mvc = MockMvcBuilders.webAppContextSetup(context).build();
    }
    @AfterEach void close() { context.close(); }

    @Test void resolvedRouteCannotBypassBudgetWithAlternateNumericId() throws Exception {
        doThrow(new RateLimitExceededException(90)).when(limiter).check(IMAGE_QUALITY, user.getName());
        for (String id : java.util.List.of("1", "+1", "0001")) {
            mvc.perform(post("/api/v1/inspections/" + id + "/image-quality").principal(user))
                    .andExpect(status().isTooManyRequests()).andExpect(header().string("Retry-After", "90"));
        }
        verify(limiter, times(3)).check(IMAGE_QUALITY, user.getName());
        verifyNoInteractions(context.getBean(DamageInspectionService.class));
    }

    @Test void ordinaryStatusPollingDoesNotConsumeExternalCallBudget() throws Exception {
        mvc.perform(get("/api/v1/inspections/1").principal(user)).andExpect(status().isOk());
        verifyNoInteractions(limiter);
        verify(context.getBean(DamageInspectionService.class)).getMyInspectionById(1L, user.getName());
    }

    @Test void failedAnalysisOrReportRetriesCannotBypassAttemptBudget() throws Exception {
        doThrow(new RateLimitExceededException(90)).when(limiter).check(INSPECTION_AI, user.getName());
        for (String operation : java.util.List.of("analyze", "report")) {
            mvc.perform(post("/api/v1/inspections/1/" + operation).principal(user))
                    .andExpect(status().isTooManyRequests());
        }
        verify(limiter, times(2)).check(INSPECTION_AI, user.getName());
        verifyNoInteractions(context.getBean(DamageInspectionService.class));
    }

    @Configuration @EnableWebMvc
    @Import({ExternalRequestRateLimitConfig.class, DamageInspectionController.class, GlobalExceptionHandler.class})
    static class Config {
        @Bean RequestRateLimiter limiter() { return mock(RequestRateLimiter.class); }
        @Bean DamageInspectionService inspections() { return mock(DamageInspectionService.class); }
        @Bean NearbyServiceService nearby() { return mock(NearbyServiceService.class); }
        @Bean com.gorkem.vehicle_inspector.service.CreditWalletService wallets() {
            return mock(com.gorkem.vehicle_inspector.service.CreditWalletService.class);
        }
        @Bean com.gorkem.vehicle_inspector.service.AnalysisCreditService analysisCredits() {
            return mock(com.gorkem.vehicle_inspector.service.AnalysisCreditService.class);
        }
    }
}
