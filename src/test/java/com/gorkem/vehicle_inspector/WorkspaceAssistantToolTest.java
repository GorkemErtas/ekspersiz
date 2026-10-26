package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException;
import com.gorkem.vehicle_inspector.repository.*;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.*;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.context.request.RequestContextHolder;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class WorkspaceAssistantToolTest {
    @AfterEach void cleanup() { RequestContextHolder.resetRequestAttributes(); }

    @Test void toolsUseSelectedWorkspaceAndRejectCrossWorkspaceIdsAndRevocation() {
        var users = mock(UserRepository.class);
        var members = mock(BusinessMemberRepository.class);
        var subscriptions = mock(SubscriptionService.class);
        var vehicles = mock(VehicleRepository.class);
        var reminders = mock(VehicleReminderRepository.class);
        var inspections = mock(DamageInspectionRepository.class);
        var user = new User("Member", "member@example.com", "hash");
        ReflectionTestUtils.setField(user, "id", 1L);
        var company = new BusinessAccount("Company");
        ReflectionTestUtils.setField(company, "id", 7L);
        var member = new BusinessMember(company, user, BusinessRole.MEMBER);
        when(users.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
        when(members.findByUserId(1L)).thenReturn(Optional.of(member));
        when(members.findByBusinessAccountIdAndRole(7L, BusinessRole.OWNER)).thenReturn(Optional.of(member));
        when(subscriptions.getEffectivePlan(user)).thenReturn(SubscriptionPlan.BUSINESS);
        var personal = new Vehicle("OWN", "Own", "Car", 2024, 1000, user);
        var shared = new Vehicle("SHARED", "Company", "Car", 2024, 1000, company);
        ReflectionTestUtils.setField(personal, "id", 11L);
        ReflectionTestUtils.setField(shared, "id", 12L);
        when(vehicles.findAllByUserIdAndArchivedFalseOrderByIdDesc(1L)).thenReturn(List.of(personal));
        when(vehicles.findAllByBusinessAccountIdAndArchivedFalseOrderByIdDesc(7L)).thenReturn(List.of(shared));
        var context = new BusinessContextService(users, members, subscriptions);
        var tools = new AiAssistantToolService(context, vehicles,
                new VehicleAccessService(vehicles, context), reminders, inspections);
        WorkspaceResolverTest.request("PERSONAL");
        assertEquals(List.of(11L), tools.getMyVehicles(user.getEmail()).stream().map(v -> v.id()).toList());
        assertThrows(ResourceNotFoundException.class, () -> tools.getVehicle(12L, user.getEmail()));
        WorkspaceResolverTest.request("BUSINESS");
        assertEquals(List.of(12L), tools.getMyVehicles(user.getEmail()).stream().map(v -> v.id()).toList());
        assertThrows(ResourceNotFoundException.class, () -> tools.getUpcomingReminders(11L, user.getEmail()));
        verifyNoInteractions(reminders, inspections);
        when(members.findByUserId(1L)).thenReturn(Optional.empty());
        assertThrows(WorkspaceAccessDeniedException.class, () -> tools.getMyVehicles(user.getEmail()));
    }
}
