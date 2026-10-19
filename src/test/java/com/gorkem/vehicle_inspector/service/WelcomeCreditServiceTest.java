package com.gorkem.vehicle_inspector.service;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.web.client.RestTemplate;
import tools.jackson.databind.ObjectMapper;
import java.time.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class WelcomeCreditServiceTest {
    private final Clock clock=Clock.fixed(Instant.parse("2026-10-19T10:00:00Z"),ZoneOffset.UTC);
    private final WelcomeCreditService service=new WelcomeCreditService(mock(JdbcTemplate.class),
            mock(CreditWalletService.class),mock(RestTemplate.class),clock,mock(PlatformTransactionManager.class),
            "test-key-at-least-thirty-two-characters","com.gorkem.ekspersiz","certificate","123");
    private String token() {
        return """
          {"tokenPayloadExternal":{"requestDetails":{"requestHash":"challenge","requestPackageName":"com.gorkem.ekspersiz","timestampMillis":%d},
          "appIntegrity":{"packageName":"com.gorkem.ekspersiz","appRecognitionVerdict":"PLAY_RECOGNIZED","certificateSha256Digest":["certificate"]},
          "accountDetails":{"appLicensingVerdict":"LICENSED"},"deviceIntegrity":{"deviceRecognitionVerdict":["MEETS_DEVICE_INTEGRITY"]}}}
          """.formatted(clock.millis());
    }
    @Test void acceptsOnlyFreshBoundLicensedAppAndDeviceVerdicts() {
        var json=new ObjectMapper();
        assertDoesNotThrow(() -> service.validate(json.readTree(token()),"challenge"));
        for(String invalid:new String[]{token().replace("challenge","other"),token().replace("certificate","wrong"),
                token().replace("LICENSED","UNLICENSED"),token().replace("MEETS_DEVICE_INTEGRITY","MEETS_BASIC_INTEGRITY"),
                token().replace("PLAY_RECOGNIZED","UNRECOGNIZED_VERSION"),token().replace("com.gorkem.ekspersiz","other.package"),
                token().replace(Long.toString(clock.millis()),Long.toString(clock.millis()-180001)),
                token().replace(Long.toString(clock.millis()),Long.toString(clock.millis()+1))}) {
            assertThrows(IllegalStateException.class,() -> service.validate(json.readTree(invalid),"challenge"));
        }
        assertThrows(IllegalStateException.class,() -> service.validate(null,"challenge"));
    }
}
