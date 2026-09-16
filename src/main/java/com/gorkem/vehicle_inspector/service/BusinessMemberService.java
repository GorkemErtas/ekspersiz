package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.response.BusinessMemberResponse;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class BusinessMemberService {

    private final BusinessContextService businessContextService;
    private final BusinessMemberRepository businessMemberRepository;

    public BusinessMemberService(
            BusinessContextService businessContextService,
            BusinessMemberRepository businessMemberRepository
    ) {
        this.businessContextService = businessContextService;
        this.businessMemberRepository = businessMemberRepository;
    }

    @Transactional(readOnly = true)
    public List<BusinessMemberResponse> getEmployees(String ownerEmail) {
        BusinessMember ownerMembership = requireOwner(ownerEmail);

        return businessMemberRepository
                .findAllByBusinessAccountIdAndRoleOrderByUserFullNameAsc(
                        ownerMembership.getBusinessAccount().getId(),
                        BusinessRole.MEMBER
                )
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public void removeEmployee(String ownerEmail, Long membershipId) {
        BusinessMember ownerMembership = requireOwner(ownerEmail);

        BusinessMember employee = businessMemberRepository
                .findByIdAndBusinessAccountId(
                        membershipId,
                        ownerMembership.getBusinessAccount().getId()
                )
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Şirket çalışanı bulunamadı."
                ));

        if (employee.getRole() == BusinessRole.OWNER) {
            throw new IllegalArgumentException(
                    "Şirket sahibi üyelikten çıkarılamaz."
            );
        }

        businessMemberRepository.delete(employee);
    }

    private BusinessMember requireOwner(String email) {
        User user = businessContextService.requireUser(email);
        return businessContextService.requireOwner(user);
    }

    private BusinessMemberResponse toResponse(BusinessMember member) {
        User user = member.getUser();

        return new BusinessMemberResponse(
                member.getId(),
                user.getId(),
                user.getFullName(),
                user.getEmail(),
                member.getRole()
        );
    }
}
