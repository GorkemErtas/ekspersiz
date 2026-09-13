package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.repository.UserRepository;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.beans.factory.annotation.Value;

import java.security.SecureRandom;
import java.time.LocalDateTime;

@Service
public class EmailVerificationService {

    private static final int VERIFICATION_CODE_BOUND = 1_000_000;
    private static final int VERIFICATION_CODE_LENGTH = 6;
    private static final int VERIFICATION_CODE_EXPIRATION_MINUTES = 5;

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JavaMailSender mailSender;

    private final SecureRandom secureRandom = new SecureRandom();

    @Value("${spring.mail.username}")
    private String mailFrom;

    public EmailVerificationService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JavaMailSender mailSender
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.mailSender = mailSender;
    }

    @Transactional
    public void createAndSendVerificationCode(User user) {
        String verificationCode = generateVerificationCode();

        user.setEmailVerificationCode(
                passwordEncoder.encode(verificationCode),
                LocalDateTime.now()
                        .plusMinutes(
                                VERIFICATION_CODE_EXPIRATION_MINUTES
                        )
        );

        userRepository.save(user);

        sendVerificationEmail(
                user.getEmail(),
                user.getFullName(),
                verificationCode
        );
    }

    private String generateVerificationCode() {
        int value = secureRandom.nextInt(VERIFICATION_CODE_BOUND);

        return String.format(
                "%0" + VERIFICATION_CODE_LENGTH + "d",
                value
        );
    }

    private void sendVerificationEmail(
            String email,
            String fullName,
            String verificationCode
    ) {
        SimpleMailMessage message = new SimpleMailMessage();

        message.setFrom(mailFrom);
        message.setTo(email);
        message.setSubject(
                "Vehicle Inspector - E-posta Doğrulama Kodu"
        );
        message.setText(
                "Merhaba " + fullName + ",\n\n"
                        + "Vehicle Inspector hesabınızı doğrulamak için "
                        + "aşağıdaki kodu kullanın:\n\n"
                        + verificationCode
                        + "\n\nBu kod "
                        + VERIFICATION_CODE_EXPIRATION_MINUTES
                        + " dakika boyunca geçerlidir.\n\n"
                        + "Bu kaydı siz oluşturmadıysanız "
                        + "bu e-postayı görmezden gelebilirsiniz."
        );

        mailSender.send(message);
    }
}
