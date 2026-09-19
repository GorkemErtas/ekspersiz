package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.dto.request.ForgotPasswordRequest;
import com.gorkem.vehicle_inspector.dto.request.ResetPasswordRequest;
import com.gorkem.vehicle_inspector.entity.PasswordResetCode;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.PasswordResetCodeRepository;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class PasswordResetService {

    private static final int RESET_CODE_EXPIRATION_MINUTES = 5;

    private final UserRepository userRepository;
    private final PasswordResetCodeRepository passwordResetCodeRepository;
    private final VerificationCodeService verificationCodeService;
    private final PasswordEncoder passwordEncoder;
    private final JavaMailSender mailSender;
    private final Clock clock;

    @Value("${spring.mail.username}")
    private String mailFrom;

    public PasswordResetService(
            UserRepository userRepository,
            PasswordResetCodeRepository passwordResetCodeRepository,
            VerificationCodeService verificationCodeService,
            PasswordEncoder passwordEncoder,
            JavaMailSender mailSender,
            Clock clock
    ) {
        this.userRepository = userRepository;
        this.passwordResetCodeRepository = passwordResetCodeRepository;
        this.verificationCodeService = verificationCodeService;
        this.passwordEncoder = passwordEncoder;
        this.mailSender = mailSender;
        this.clock = clock;
    }

    @Transactional
    public void requestReset(ForgotPasswordRequest request) {
        String email = normalizeEmail(request.getEmail());

        Optional<User> optionalUser =
                userRepository.findByEmail(email);

        if (optionalUser.isEmpty()) {
            return;
        }

        User user = optionalUser.get();

        String code = verificationCodeService.generate();
        String codeHash = verificationCodeService.hash(code);

        LocalDateTime now = LocalDateTime.now(clock);
        LocalDateTime expiresAt =
                now.plusMinutes(RESET_CODE_EXPIRATION_MINUTES);

        passwordResetCodeRepository.deleteByUserId(user.getId());

        PasswordResetCode resetCode =
                new PasswordResetCode(
                        user,
                        codeHash,
                        expiresAt,
                        now
                );

        passwordResetCodeRepository.save(resetCode);

        sendResetEmail(user, code);
    }

    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        String email = normalizeEmail(request.getEmail());

        User user = userRepository.findByEmail(email)
                .orElseThrow(() ->
                        new IllegalArgumentException(
                                "Şifre sıfırlama bilgileri geçersiz."
                        )
                );

        PasswordResetCode resetCode =
                passwordResetCodeRepository
                        .findByUserId(user.getId())
                        .orElseThrow(() ->
                                new IllegalArgumentException(
                                        "Şifre sıfırlama bilgileri geçersiz."
                                )
                        );

        LocalDateTime now = LocalDateTime.now(clock);

        if (resetCode.isExpired(now)) {
            passwordResetCodeRepository.delete(resetCode);

            throw new IllegalArgumentException(
                    "Şifre sıfırlama kodunun süresi dolmuş."
            );
        }

        if (!verificationCodeService.matches(
                request.getCode(),
                resetCode.getCodeHash()
        )) {
            throw new IllegalArgumentException(
                    "Şifre sıfırlama kodu hatalı."
            );
        }

        if (!request.getNewPassword().equals(
                request.getConfirmNewPassword()
        )) {
            throw new IllegalArgumentException(
                    "Yeni şifreler eşleşmiyor."
            );
        }

        if (passwordEncoder.matches(
                request.getNewPassword(),
                user.getPassword()
        )) {
            throw new IllegalArgumentException(
                    "Yeni şifre mevcut şifreden farklı olmalıdır."
            );
        }

        user.setPassword(
                passwordEncoder.encode(
                        request.getNewPassword()
                )
        );

        userRepository.save(user);

        passwordResetCodeRepository.delete(resetCode);
    }

    private void sendResetEmail(
            User user,
            String code
    ) {
        SimpleMailMessage message = new SimpleMailMessage();

        message.setFrom(mailFrom);
        message.setTo(user.getEmail());
        message.setSubject(
                "Vehicle Inspector - Şifre Sıfırlama Kodu"
        );

        message.setText(
                "Merhaba " + user.getFullName() + ",\n\n"
                        + "Şifrenizi sıfırlamak için aşağıdaki kodu kullanın:\n\n"
                        + code
                        + "\n\nBu kod "
                        + RESET_CODE_EXPIRATION_MINUTES
                        + " dakika boyunca geçerlidir.\n\n"
                        + "Bu işlemi siz başlatmadıysanız "
                        + "bu e-postayı görmezden gelebilirsiniz."
        );

        mailSender.send(message);
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }
}