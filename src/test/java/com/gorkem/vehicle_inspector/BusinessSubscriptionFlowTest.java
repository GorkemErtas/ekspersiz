package com.gorkem.vehicle_inspector;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.gorkem.vehicle_inspector.client.*;
import com.gorkem.vehicle_inspector.dto.request.CreateBusinessAccountRequest;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import com.gorkem.vehicle_inspector.service.billing.RevenueCatWebhookVerifier;
import org.junit.jupiter.api.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** Real service chain with provider/repository boundaries stubbed; no live payment or database. */
class BusinessSubscriptionFlowTest {
    @AfterEach void clearRequest() { RequestContextHolder.resetRequestAttributes(); }

    @ParameterizedTest @ValueSource(booleans = {false, true})
    void verifiedSubscriptionRequiresExplicitCompanyCreationAndWorkspaceSelection(boolean sandbox) {
        var clock = Clock.fixed(Instant.parse("2026-10-26T10:00:00Z"), ZoneOffset.UTC);
        var users = mock(UserRepository.class);
        var members = mock(BusinessMemberRepository.class);
        var companies = mock(BusinessAccountRepository.class);
        var subscriptions = mock(BillingSubscriptionRepository.class);
        var provider = mock(RevenueCatClient.class);
        var membership = new AtomicReference<BusinessMember>();
        var storedSubscription = new AtomicReference<BillingSubscription>();
        var user = new User("Buyer", "buyer@example.com", "unused");
        ReflectionTestUtils.setField(user, "id", 1L);
        when(users.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(users.findByEmailForUpdate(user.getEmail())).thenReturn(Optional.of(user));
        when(members.findByUserId(1L)).thenAnswer(i -> Optional.ofNullable(membership.get()));
        when(members.existsByUserId(1L)).thenAnswer(i -> membership.get() != null);
        when(members.save(any())).thenAnswer(i -> { membership.set(i.getArgument(0)); return membership.get(); });
        when(companies.save(any())).thenAnswer(i -> {
            BusinessAccount company = i.getArgument(0);
            ReflectionTestUtils.setField(company, "id", 7L);
            return company;
        });
        when(subscriptions.findByUserId(1L)).thenAnswer(i -> Optional.ofNullable(storedSubscription.get()));
        when(subscriptions.save(any())).thenAnswer(i -> { storedSubscription.set(i.getArgument(0)); return storedSubscription.get(); });
        when(provider.getCustomer(user.getBillingCustomerId())).thenReturn(new RevenueCatCustomer(List.of(
                new RevenueCatSubscription("eksper_business_monthly:monthly", clock.instant(),
                        clock.instant().plusSeconds(86400), null, true, false, false, sandbox, "play_store")
        ), List.of(), null, user.getBillingCustomerId()));
        var plans = new SubscriptionService(mock(AnalysisUsageRepository.class), mock(VehicleRepository.class), clock);
        var context = new BusinessContextService(users, members, plans);
        var billing = new BillingService(users, subscriptions, mock(BillingWebhookEventRepository.class), plans,
                provider, mock(RevenueCatWebhookVerifier.class), new ObjectMapper(), clock);
        var business = new BusinessAccountService(companies, members, users, plans);
        var policy = mock(com.gorkem.vehicle_inspector.service.billing.BusinessBillingPolicy.class);
        when(policy.allowsSandboxSubscription(user)).thenReturn(true);
        when(policy.sandboxSubscription(user)).thenAnswer(i -> storedSubscription.get() != null && storedSubscription.get().isSandbox());
        for (Object component : List.of(plans, context, billing, business)) ReflectionTestUtils.setField(component,"businessBilling",policy);
        var auth = new AuthService(users, null, null, null, null, context, plans, null);

        var synced = billing.sync(user.getEmail()); // No webhook needed for reconciliation.
        assertEquals(SubscriptionPlan.BUSINESS, synced.status().currentPlan());
        assertEquals("VERIFIED", synced.status().verificationStatus());
        assertEquals(sandbox, synced.status().sandbox());
        assertNull(auth.getCurrentUser(user.getEmail()).getBusinessAccount());
        verifyNoInteractions(companies);
        select("BUSINESS");
        assertThrows(WorkspaceAccessDeniedException.class, () -> context.workspace(user));

        select("PERSONAL");
        business.create(user.getEmail(), new CreateBusinessAccountRequest("  Buyer's Company  "));
        var refreshed = auth.getCurrentUser(user.getEmail());
        assertEquals(7L, refreshed.getBusinessAccount().id());
        assertEquals(BusinessRole.OWNER, refreshed.getBusinessAccount().role());
        assertEquals("Buyer's Company", refreshed.getBusinessAccount().companyName());
        assertEquals(sandbox, refreshed.getBusinessAccount().sandbox());
        assertEquals("user:1", context.workspace(user).accountId());
        select("BUSINESS");
        assertEquals("business:7", context.workspace(user).accountId());
        assertThrows(IllegalStateException.class, () -> business.create(user.getEmail(),
                new CreateBusinessAccountRequest("Do not duplicate")));
        verify(companies, times(1)).save(any());

        membership.set(null); // Revoked on another device.
        select("BUSINESS");
        assertThrows(WorkspaceAccessDeniedException.class, () -> context.workspace(user));
        select("PERSONAL");
        assertEquals("user:1", context.workspace(user).accountId());
        assertNull(auth.getCurrentUser(user.getEmail()).getBusinessAccount());
    }

    private void select(String workspace) {
        var request = new MockHttpServletRequest();
        request.addHeader("X-Workspace", workspace);
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
    }
}
