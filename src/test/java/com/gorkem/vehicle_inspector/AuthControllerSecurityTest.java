package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.controller.AuthController;
import com.gorkem.vehicle_inspector.exception.GlobalExceptionHandler;
import com.gorkem.vehicle_inspector.exception.RateLimitExceededException;
import com.gorkem.vehicle_inspector.security.RequestRateLimiter;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static com.gorkem.vehicle_inspector.security.RequestRateLimiter.Action.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class AuthControllerSecurityTest {
    @Test void exhaustedResetBudgetReturns429WithoutTryingCode() throws Exception {
        var limiter = mock(RequestRateLimiter.class);
        var reset = mock(PasswordResetService.class);
        doThrow(new RateLimitExceededException(300)).when(limiter).check(RESET_CHECK, "user@example.com");
        var mvc = MockMvcBuilders.standaloneSetup(new AuthController(mock(AuthService.class), reset,
                        mock(AccountDeletionService.class), limiter))
                .setControllerAdvice(new GlobalExceptionHandler()).build();
        mvc.perform(post("/api/v1/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"user@example.com","code":"123456","newPassword":"new-password","confirmNewPassword":"new-password"}
                """))
                .andExpect(status().isTooManyRequests()).andExpect(header().string("Retry-After", "300"));
        verifyNoInteractions(reset);
    }
}
