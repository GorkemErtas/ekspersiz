package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.CreateBusinessAccountRequest;
import com.gorkem.vehicle_inspector.dto.response.BusinessAccountResponse;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.BusinessAccountRepository;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BusinessAccountService {
    @org.springframework.beans.factory.annotation.Autowired
    private com.gorkem.vehicle_inspector.service.billing.BusinessBillingPolicy businessBilling;

    private final BusinessAccountRepository businessAccountRepository;
    private final BusinessMemberRepository businessMemberRepository;
    private final UserRepository userRepository;
    private final SubscriptionService subscriptionService;

    public BusinessAccountService(
            BusinessAccountRepository businessAccountRepository,
            BusinessMemberRepository businessMemberRepository,
            UserRepository userRepository,
            SubscriptionService subscriptionService
    ) {
        this.businessAccountRepository = businessAccountRepository;

        this.businessMemberRepository = businessMemberRepository;

        this.userRepository = userRepository;
        this.subscriptionService = subscriptionService;
    }

    @Transactional
    public BusinessAccountResponse create(
            String email,
            CreateBusinessAccountRequest request
    ) {
        User user = userRepository.findByEmailForUpdate(
                        normalizeEmail(email)
                )
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );

        if (businessMemberRepository.existsByUserId(user.getId())) {
            throw new IllegalStateException(
                    "Kullanıcı zaten bir şirkete bağlı."
            );
        }

        if (subscriptionService.getEffectivePlan(user)
                != SubscriptionPlan.BUSINESS) {

            throw new IllegalStateException(
                    "Şirket ortamı oluşturmak için Kurumsal plan gereklidir."
            );
        }

        BusinessAccount businessAccount =
                new BusinessAccount(
                        request.companyName().trim(),
                        businessBilling != null && businessBilling.sandboxSubscription(user)
                );

        BusinessAccount savedBusinessAccount =
                businessAccountRepository.save(businessAccount);

        BusinessMember owner =
                new BusinessMember(
                        savedBusinessAccount,
                        user,
                        BusinessRole.OWNER
                );

        businessMemberRepository.saveAndFlush(owner);

        return toResponse(
                savedBusinessAccount,
                owner
        );
    }

    private BusinessAccountResponse toResponse(
            BusinessAccount businessAccount,
            BusinessMember member
    ) {
        return new BusinessAccountResponse(
                businessAccount.getId(),
                businessAccount.getCompanyName(),
                member.getRole(),
                businessAccount.isSandbox(),
                businessBilling == null ? com.gorkem.vehicle_inspector.service.workspace.BusinessWorkspaceAccess.UNKNOWN
                        : businessBilling.workspaceAccess(member.getUser(), businessAccount.getId())
        );
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }
}
