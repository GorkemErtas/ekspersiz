package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.CreateBusinessInvitationRequest;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.BusinessInvitationRepository;
import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BusinessInvitationService {

    private final UserRepository userRepository;
    private final BusinessMemberRepository businessMemberRepository;
    private final BusinessInvitationRepository businessInvitationRepository;
    private final VerificationCodeService verificationCodeService;
    private final JavaMailSender mailSender;
    private final SubscriptionService subscriptionService;

    @Value("${spring.mail.username}")
    private String mailFrom;

    public BusinessInvitationService(
            UserRepository userRepository,
            BusinessMemberRepository businessMemberRepository,
            BusinessInvitationRepository businessInvitationRepository,
            VerificationCodeService verificationCodeService,
            JavaMailSender mailSender,
            SubscriptionService subscriptionService
    ) {
        this.userRepository = userRepository;
        this.businessMemberRepository = businessMemberRepository;
        this.businessInvitationRepository = businessInvitationRepository;
        this.verificationCodeService = verificationCodeService;
        this.mailSender = mailSender;
        this.subscriptionService = subscriptionService;
    }

    @Transactional
    public void invite(
            String ownerEmail,
            CreateBusinessInvitationRequest request
    ) {
        User owner = findUser(ownerEmail);

        BusinessMember ownerMembership =
                businessMemberRepository.findByUserId(owner.getId())
                        .orElseThrow(() ->
                                new IllegalStateException(
                                        "Şirket üyeliği bulunamadı."
                                )
                        );

        if (ownerMembership.getRole() != BusinessRole.OWNER) {
            throw new IllegalStateException(
                    "Yalnızca şirket sahibi çalışan davet edebilir."
            );
        }

        if (subscriptionService.getEffectivePlan(owner)
                != SubscriptionPlan.BUSINESS) {
            throw new IllegalStateException(
                    "Şirket işlemleri için Kurumsal plan gereklidir."
            );
        }

        User invitedUser = findUser(request.email());

        if (owner.getId().equals(invitedUser.getId())) {
            throw new IllegalArgumentException(
                    "Kendinizi şirkete davet edemezsiniz."
            );
        }

        if (businessMemberRepository.existsByUserId(
                invitedUser.getId()
        )) {
            throw new IllegalStateException(
                    "Kullanıcı zaten bir şirkete bağlı."
            );
        }

        BusinessAccount businessAccount =
                ownerMembership.getBusinessAccount();

        String code = verificationCodeService.generate();
        String codeHash = verificationCodeService.hash(code);

        BusinessInvitation invitation =
                businessInvitationRepository
                        .findByBusinessAccountIdAndUserId(
                                businessAccount.getId(),
                                invitedUser.getId()
                        )
                        .map(existing -> {
                            existing.refresh(codeHash);
                            return existing;
                        })
                        .orElseGet(() ->
                                new BusinessInvitation(
                                        businessAccount,
                                        invitedUser,
                                        codeHash
                                )
                        );

        businessInvitationRepository.save(invitation);

        sendInvitationEmail(
                invitedUser,
                businessAccount,
                code
        );
    }

    @Transactional
    public void accept(
            String email,
            String code
    ) {
        User user = findUser(email);

        if (businessMemberRepository.existsByUserId(user.getId())) {
            throw new IllegalStateException(
                    "Kullanıcı zaten bir şirkete bağlı."
            );
        }

        BusinessInvitation invitation =
                businessInvitationRepository.findByUserId(user.getId())
                        .orElseThrow(() ->
                                new ResourceNotFoundException(
                                        "Bekleyen şirket daveti bulunamadı."
                                )
                        );

        if (invitation.isExpired()) {
            businessInvitationRepository.delete(invitation);

            throw new IllegalArgumentException(
                    "Davet kodunun süresi dolmuş."
            );
        }

        if (!verificationCodeService.matches(
                code,
                invitation.getCodeHash()
        )) {
            throw new IllegalArgumentException(
                    "Davet kodu hatalı."
            );
        }

        BusinessMember member =
                new BusinessMember(
                        invitation.getBusinessAccount(),
                        user,
                        BusinessRole.MEMBER
                );

        businessMemberRepository.save(member);

        businessInvitationRepository.delete(invitation);
    }

    private User findUser(String email) {
        String normalizedEmail =
                email.trim().toLowerCase();

        return userRepository.findByEmail(normalizedEmail)
                .orElseThrow(() ->
                        new ResourceNotFoundException(
                                "Kullanıcı bulunamadı."
                        )
                );
    }

    private void sendInvitationEmail(
            User user,
            BusinessAccount businessAccount,
            String code
    ) {
        SimpleMailMessage message = new SimpleMailMessage();

        message.setFrom(mailFrom);
        message.setTo(user.getEmail());
        message.setSubject(
                "EksperSiz - Şirket Daveti"
        );

        message.setText(
                "Merhaba " + user.getFullName() + ",\n\n"
                        + businessAccount.getCompanyName()
                        + " sizi EksperSiz şirket hesabına davet etti.\n\n"
                        + "Davet kodunuz:\n\n"
                        + code
                        + "\n\nBu kod 15 dakika boyunca geçerlidir."
        );

        mailSender.send(message);
    }
}
