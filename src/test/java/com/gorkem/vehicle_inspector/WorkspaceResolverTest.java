package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException;
import com.gorkem.vehicle_inspector.service.workspace.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Optional;
import java.util.concurrent.Executors;
import static org.junit.jupiter.api.Assertions.*;

class WorkspaceResolverTest {
    private final WorkspaceResolver resolver = new WorkspaceResolver();
    private final User user = new User("Member", "member@example.com", "hash");
    private BusinessMember member;

    @BeforeEach void setup() {
        ReflectionTestUtils.setField(user, "id", 1L);
        var business = new BusinessAccount("Company");
        ReflectionTestUtils.setField(business, "id", 7L);
        member = new BusinessMember(business, user, BusinessRole.MEMBER);
    }
    @AfterEach void clear() { RequestContextHolder.resetRequestAttributes(); }
    static MockHttpServletRequest request(String selection) {
        var request = new MockHttpServletRequest();
        if (selection != null) request.addHeader(WorkspaceResolver.HEADER, selection);
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
        return request;
    }
    @Test void oldClientsKeepMembershipDefaultAndPersonalClientsRemainPersonal() {
        request(null);
        assertTrue(resolver.resolve(1L, Optional.of(member)).business());
        request(null);
        assertFalse(resolver.resolve(1L, Optional.empty()).business());
        request("PERSONAL");
        assertEquals("user:1", resolver.resolve(1L, Optional.of(member)).accountId());
    }
    @Test void businessIdIsServerDerivedAndRemovalCannotSilentlySelectPersonal() {
        var request = request("BUSINESS");
        request.addHeader("X-Business-Id", "999");
        assertEquals("business:7", resolver.resolve(1L, Optional.of(member)).accountId());
        assertThrows(WorkspaceAccessDeniedException.class, () -> resolver.resolve(1L, Optional.empty()));
        assertThrows(WorkspaceAccessDeniedException.class, () -> resolver.resolve(2L, Optional.of(member)));
        var another = new BusinessAccount("Other");
        ReflectionTestUtils.setField(another, "id", 8L);
        assertThrows(WorkspaceAccessDeniedException.class,
                () -> resolver.resolve(1L, Optional.of(new BusinessMember(another, user, BusinessRole.MEMBER))));
    }
    @Test void nonMemberCannotSelectBusiness() {
        request("BUSINESS");
        assertThrows(WorkspaceAccessDeniedException.class, () -> resolver.resolve(1L, Optional.empty()));
    }
    @ParameterizedTest @ValueSource(strings = {"", "personal", "BUSINESS:7", "PERSONAL,BUSINESS", "7"})
    void malformedSelectionIsRejected(String header) {
        request(header);
        assertThrows(IllegalArgumentException.class, () -> resolver.resolve(1L, Optional.of(member)));
    }
    @Test void duplicateHeadersAreRejected() {
        request("PERSONAL").addHeader(WorkspaceResolver.HEADER, "BUSINESS");
        assertThrows(IllegalArgumentException.class, () -> resolver.resolve(1L, Optional.of(member)));
    }
    @Test void parallelRequestsDoNotShareWorkspaceState() throws Exception {
        try (var executor = Executors.newFixedThreadPool(2)) {
            var personal = executor.submit(() -> {
                try { request("PERSONAL"); return resolver.resolve(1L, Optional.of(member)); }
                finally { RequestContextHolder.resetRequestAttributes(); }
            });
            var business = executor.submit(() -> {
                try { request("BUSINESS"); return resolver.resolve(1L, Optional.of(member)); }
                finally { RequestContextHolder.resetRequestAttributes(); }
            });
            assertEquals("user:1", personal.get().accountId());
            assertEquals("business:7", business.get().accountId());
        }
    }
}
