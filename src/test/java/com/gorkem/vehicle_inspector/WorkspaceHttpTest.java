package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.config.WorkspaceWebConfig;
import com.gorkem.vehicle_inspector.controller.WorkspaceController;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.GlobalExceptionHandler;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.security.AuthenticatedUser;
import com.gorkem.vehicle_inspector.service.*;
import com.gorkem.vehicle_inspector.service.workspace.WorkspaceResolver;
import org.junit.jupiter.api.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.context.request.RequestContextHolder;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class WorkspaceHttpTest {
    BusinessMemberRepository members;
    User user;
    BusinessMember member;
    MockMvc mvc;
    static class Registry extends InterceptorRegistry {
        List<Object> values() { return getInterceptors(); }
    }
    @BeforeEach void setup() {
        var users = mock(UserRepository.class);
        members = mock(BusinessMemberRepository.class);
        user = new User("Member", "member@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", 1L);
        var company = new BusinessAccount("Company");
        ReflectionTestUtils.setField(company, "id", 7L);
        member = new BusinessMember(company, user, BusinessRole.MEMBER);
        when(users.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(members.findByUserId(1L)).thenReturn(Optional.of(member));
        var context = new BusinessContextService(users, members, mock(SubscriptionService.class));
        var registry = new Registry();
        new WorkspaceWebConfig(context, members, new WorkspaceResolver()).addInterceptors(registry);
        mvc = MockMvcBuilders.standaloneSetup(new WorkspaceController(context))
                .defaultRequest(get("/").principal(new UsernamePasswordAuthenticationToken(
                        new AuthenticatedUser(user), null, List.of())))
                .setControllerAdvice(new GlobalExceptionHandler())
                .addInterceptors((HandlerInterceptor)registry.values().getFirst()).build();
        var identity = new AuthenticatedUser(user);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(identity, null, identity.getAuthorities()));
    }
    @AfterEach void clear() {
        SecurityContextHolder.clearContext(); RequestContextHolder.resetRequestAttributes();
    }
    @Test void explicitPersonalAndLegacyBusinessAreResolvedForTheSameAuthenticatedUser() throws Exception {
        mvc.perform(get("/api/v1/workspace").header("X-Workspace", "PERSONAL"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.type").value("PERSONAL"))
                .andExpect(jsonPath("$.userId").value(1));
        mvc.perform(get("/api/v1/workspace").header("X-Business-Id", "999"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.type").value("BUSINESS"))
                .andExpect(jsonPath("$.businessId").value(7));
    }
    @Test void invalidHeaderAndRevokedMembershipAreRejected() throws Exception {
        mvc.perform(get("/api/v1/workspace").header("X-Workspace", "BUSINESS:999"))
                .andExpect(status().isBadRequest());
        when(members.findByUserId(1L)).thenReturn(Optional.empty());
        mvc.perform(get("/api/v1/workspace").header("X-Workspace", "BUSINESS"))
                .andExpect(status().isForbidden()).andExpect(jsonPath("$.validationErrors.code").value("WORKSPACE_UNAVAILABLE"));
        mvc.perform(get("/api/v1/workspace").header("X-Workspace", "PERSONAL"))
                .andExpect(status().isOk());
    }
}
