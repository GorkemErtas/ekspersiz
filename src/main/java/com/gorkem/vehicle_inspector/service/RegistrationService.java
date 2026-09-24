package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.RegisterRequest;
import com.gorkem.vehicle_inspector.dto.request.ResendVerificationRequest;
import com.gorkem.vehicle_inspector.dto.request.VerifyEmailRequest;
import com.gorkem.vehicle_inspector.entity.PendingRegistration;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.DuplicateResourceException;
import com.gorkem.vehicle_inspector.exception.ResourceNotFoundException;
import com.gorkem.vehicle_inspector.repository.BusinessInvitationRepository;
import com.gorkem.vehicle_inspector.repository.PendingRegistrationRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class RegistrationService {

    private static final int VERIFICATION_CODE_EXPIRATION_MINUTES = 5;

    private final UserRepository userRepository;
    private final PendingRegistrationRepository pendingRegistrationRepository;
    private final BusinessInvitationRepository businessInvitationRepository;
    private final PasswordEncoder passwordEncoder;
    private final VerificationCodeService verificationCodeService;
    private final EmailService emailService;
    private final Clock clock;

    public RegistrationService(
            UserRepository userRepository,
            PendingRegistrationRepository pendingRegistrationRepository,
            BusinessInvitationRepository businessInvitationRepository,
            PasswordEncoder passwordEncoder,
            VerificationCodeService verificationCodeService,
            EmailService emailService,
            Clock clock
    ) {
        this.userRepository = userRepository;
        this.pendingRegistrationRepository = pendingRegistrationRepository;
        this.businessInvitationRepository = businessInvitationRepository;
        this.passwordEncoder = passwordEncoder;
        this.verificationCodeService = verificationCodeService;
        this.emailService = emailService;
        this.clock = clock;
    }

    @Transactional
    public void start(RegisterRequest request) {
        String email = normalizeEmail(request.getEmail());

        userRepository.findByEmail(email).ifPresent(existingUser -> {
            if (existingUser.isEmailVerified()) {
                throw duplicateEmail(email);
            }

            businessInvitationRepository.deleteByUserId(existingUser.getId());
            businessInvitationRepository.flush();
            userRepository.delete(existingUser);
            userRepository.flush();
        });

        LocalDateTime now = LocalDateTime.now(clock);
        String code = verificationCodeService.generate();
        String codeHash = verificationCodeService.hash(code);
        String passwordHash = passwordEncoder.encode(request.getPassword());

        PendingRegistration pendingRegistration =
                pendingRegistrationRepository.findByEmail(email)
                        .map(existing -> {
                            existing.replaceRegistration(
                                    request.getFullName().trim(),
                                    passwordHash,
                                    codeHash,
                                    now,
                                    expiresAt(now)
                            );
                            return existing;
                        })
                        .orElseGet(() -> new PendingRegistration(
                                request.getFullName().trim(),
                                email,
                                passwordHash,
                                codeHash,
                                now,
                                expiresAt(now)
                        ));

        pendingRegistrationRepository.save(pendingRegistration);
        sendVerificationEmail(
                pendingRegistration.getEmail(),
                code
        );
    }

    @Transactional
    public void verify(VerifyEmailRequest request) {
        String email = normalizeEmail(request.getEmail());
        Optional<PendingRegistration> pending =
                pendingRegistrationRepository.findByEmailForUpdate(email);

        if (pending.isEmpty()) {
            verifyLegacyUserOrReturnIfAlreadyVerified(email, request.getCode());
            return;
        }

        PendingRegistration registration = pending.get();
        LocalDateTime now = LocalDateTime.now(clock);

        if (registration.isVerificationCodeExpired(now)) {
            throw new IllegalArgumentException(
                    "Doğrulama kodunun süresi dolmuş. Lütfen yeni kod isteyin."
            );
        }

        if (!verificationCodeService.matches(
                request.getCode(),
                registration.getVerificationCodeHash()
        )) {
            throw new IllegalArgumentException("Doğrulama kodu hatalı.");
        }

        if (userRepository.existsByEmail(email)) {
            throw duplicateEmail(email);
        }

        User user = new User(
                registration.getFullName(),
                registration.getEmail(),
                registration.getPasswordHash()
        );
        user.markEmailVerified();

        userRepository.save(user);
        pendingRegistrationRepository.delete(registration);
    }

    @Transactional
    public void resend(ResendVerificationRequest request) {
        String email = normalizeEmail(request.getEmail());
        Optional<PendingRegistration> pending =
                pendingRegistrationRepository.findByEmailForUpdate(email);

        if (pending.isEmpty()) {
            resendLegacyUserOrReject(email);
            return;
        }

        PendingRegistration registration = pending.get();
        LocalDateTime now = LocalDateTime.now(clock);
        String code = verificationCodeService.generate();

        registration.refreshCode(
                verificationCodeService.hash(code),
                now,
                expiresAt(now)
        );
        pendingRegistrationRepository.save(registration);

        sendVerificationEmail(
                registration.getEmail(),
                code
        );
    }

    private void verifyLegacyUserOrReturnIfAlreadyVerified(
            String email,
            String code
    ) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Bekleyen kayıt bulunamadı."
                ));

        if (user.isEmailVerified()) {
            return;
        }

        if (user.getEmailVerificationCodeHash() == null
                || user.isEmailVerificationCodeExpired()) {
            throw new IllegalArgumentException(
                    "Doğrulama kodunun süresi dolmuş. Lütfen yeni kod isteyin."
            );
        }

        if (!passwordEncoder.matches(code, user.getEmailVerificationCodeHash())) {
            throw new IllegalArgumentException("Doğrulama kodu hatalı.");
        }

        user.markEmailVerified();
        userRepository.save(user);
    }

    private void resendLegacyUserOrReject(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Bekleyen kayıt bulunamadı."
                ));

        if (user.isEmailVerified()) {
            throw new IllegalArgumentException(
                    "Bu e-posta adresi zaten doğrulanmış."
            );
        }

        String code = verificationCodeService.generate();
        LocalDateTime now = LocalDateTime.now(clock);
        user.setEmailVerificationCode(
                verificationCodeService.hash(code),
                expiresAt(now)
        );
        userRepository.save(user);
        sendVerificationEmail(user.getEmail(), code);
    }

    private void sendVerificationEmail(String email, String code) {
        String subject = "EksperSiz - E-posta Doğrulama Kodu";

        String content = """
            EksperSiz e-posta doğrulama kodunuz:

            %s

            Bu kod 5 dakika boyunca geçerlidir.

            Bu işlemi siz başlatmadıysanız bu e-postayı dikkate almayabilirsiniz.
            """.formatted(code);

        emailService.send(email, subject, content);
    }

    private LocalDateTime expiresAt(LocalDateTime now) {
        return now.plusMinutes(VERIFICATION_CODE_EXPIRATION_MINUTES);
    }

    private DuplicateResourceException duplicateEmail(String email) {
        return new DuplicateResourceException(
                "Bu e-posta adresi zaten kullanılıyor: " + email
        );
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }
}
