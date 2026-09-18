package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.BusinessAccount;
import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
public class BusinessContextService {

    private final UserRepository userRepository;
    private final BusinessMemberRepository businessMemberRepository;
    private final SubscriptionService subscriptionService;

    public BusinessContextService(
            UserRepository userRepository,
            BusinessMemberRepository businessMemberRepository,
            SubscriptionService subscriptionService
    ) {
        this.userRepository = userRepository;
        this.businessMemberRepository = businessMemberRepository;
        this.subscriptionService = subscriptionService;
    }

    @Transactional(readOnly = true)
    public User requireUser(String email) {
        return userRepository.findByEmail(
                        normalizeEmail(email)
                )
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );
    }

    @Transactional(readOnly = true)
    public Optional<BusinessMember> findMembership(User user) {
        return businessMemberRepository
                .findByUserId(user.getId());
    }

    @Transactional(readOnly = true)
    public boolean isBusinessMember(User user) {
        return businessMemberRepository
                .existsByUserId(user.getId());
    }

    @Transactional(readOnly = true)
    public BusinessMember requireMembership(User user) {
        return findMembership(user)
                .orElseThrow(() ->
                        new IllegalStateException(
                                "Kullanıcı bir şirkete bağlı değil."
                        )
                );
    }

    @Transactional(readOnly = true)
    public BusinessAccount requireBusinessAccount(User user) {
        BusinessAccount businessAccount = requireMembership(user)
                .getBusinessAccount();

        BusinessMember owner = businessMemberRepository
                .findByBusinessAccountIdAndRole(
                        businessAccount.getId(),
                        BusinessRole.OWNER
                )
                .orElseThrow(() -> new IllegalStateException(
                        "Şirket sahibi bulunamadı."
                ));

        if (subscriptionService.getEffectivePlan(owner.getUser())
                != SubscriptionPlan.BUSINESS) {
            throw new IllegalStateException(
                    "Şirket aboneliği aktif değil."
            );
        }

        return businessAccount;
    }

    @Transactional(readOnly = true)
    public BusinessMember requireOwner(User user) {
        BusinessMember membership =
                requireMembership(user);

        if (membership.getRole() != BusinessRole.OWNER) {
            throw new IllegalStateException(
                    "Bu işlem yalnızca business sahibi tarafından yapılabilir."
            );
        }

        if (subscriptionService.getEffectivePlan(user)
                != SubscriptionPlan.BUSINESS) {
            throw new IllegalStateException(
                    "Şirket işlemleri için Kurumsal plan gereklidir."
            );
        }

        return membership;
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }
}
