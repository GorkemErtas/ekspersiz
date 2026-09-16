package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.response.BusinessMemberResponse;
import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.BusinessMemberService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BusinessMemberServiceTest {

    @Mock
    private BusinessContextService businessContextService;

    @Mock
    private BusinessMemberRepository businessMemberRepository;

    private BusinessMemberService service;

    @BeforeEach
    void setUp() {
        service = new BusinessMemberService(
                businessContextService,
                businessMemberRepository
        );
    }

    @Test
    void ownerShouldListEmployeesWithIdentityInformation() {
        BusinessMember ownerMembership = ownerMembership(10L);
        User employee = mock(User.class);
        when(employee.getId()).thenReturn(2L);
        when(employee.getFullName()).thenReturn("Ayşe Yılmaz");
        when(employee.getEmail()).thenReturn("ayse@example.com");

        BusinessMember employeeMembership = mock(BusinessMember.class);
        when(employeeMembership.getId()).thenReturn(20L);
        when(employeeMembership.getUser()).thenReturn(employee);
        when(employeeMembership.getRole()).thenReturn(BusinessRole.MEMBER);

        when(businessMemberRepository
                .findAllByBusinessAccountIdAndRoleOrderByUserFullNameAsc(
                        10L,
                        BusinessRole.MEMBER
                ))
                .thenReturn(List.of(employeeMembership));

        List<BusinessMemberResponse> result =
                service.getEmployees("owner@example.com");

        assertEquals(1, result.size());
        assertEquals(20L, result.getFirst().id());
        assertEquals(2L, result.getFirst().userId());
        assertEquals("Ayşe Yılmaz", result.getFirst().fullName());
        assertEquals("ayse@example.com", result.getFirst().email());
        assertEquals(BusinessRole.MEMBER, result.getFirst().role());
    }

    @Test
    void ownerShouldRemoveEmployeeFromOwnBusiness() {
        ownerMembership(10L);
        BusinessMember employeeMembership = mock(BusinessMember.class);
        when(employeeMembership.getRole()).thenReturn(BusinessRole.MEMBER);
        when(businessMemberRepository.findByIdAndBusinessAccountId(20L, 10L))
                .thenReturn(Optional.of(employeeMembership));

        service.removeEmployee("owner@example.com", 20L);

        verify(businessMemberRepository).delete(employeeMembership);
    }

    @Test
    void employeeOutsideOwnersBusinessShouldNotBeRemoved() {
        ownerMembership(10L);
        when(businessMemberRepository.findByIdAndBusinessAccountId(20L, 10L))
                .thenReturn(Optional.empty());

        assertThrows(
                ResourceNotFoundException.class,
                () -> service.removeEmployee("owner@example.com", 20L)
        );

        verify(businessMemberRepository, never()).delete(any());
    }

    @Test
    void ownerMembershipShouldNotBeRemovable() {
        ownerMembership(10L);
        BusinessMember target = mock(BusinessMember.class);
        when(target.getRole()).thenReturn(BusinessRole.OWNER);
        when(businessMemberRepository.findByIdAndBusinessAccountId(20L, 10L))
                .thenReturn(Optional.of(target));

        assertThrows(
                IllegalArgumentException.class,
                () -> service.removeEmployee("owner@example.com", 20L)
        );

        verify(businessMemberRepository, never()).delete(any());
    }

    private BusinessMember ownerMembership(Long businessAccountId) {
        User owner = mock(User.class);
        BusinessAccount businessAccount = mock(BusinessAccount.class);
        BusinessMember membership = mock(BusinessMember.class);

        when(businessAccount.getId()).thenReturn(businessAccountId);
        when(membership.getBusinessAccount()).thenReturn(businessAccount);
        when(businessContextService.requireUser("owner@example.com"))
                .thenReturn(owner);
        when(businessContextService.requireOwner(owner))
                .thenReturn(membership);

        return membership;
    }
}
