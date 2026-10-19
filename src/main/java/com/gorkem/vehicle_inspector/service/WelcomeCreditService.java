package com.gorkem.vehicle_inspector.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.gorkem.vehicle_inspector.entity.User;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.web.client.RestTemplate;
import tools.jackson.databind.JsonNode;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.*;
import java.util.*;

/** Play-verified request binding plus a server HMAC of Android's signing-key scoped ID.
 * This mitigates reinstall/account churn; it is not a claim of absolute physical-device identity. */
@Service
public class WelcomeCreditService {
    private final JdbcTemplate jdbc;
    private final CreditWalletService credits;
    private final RestTemplate http;
    private final Clock clock;
    private final TransactionTemplate tx;
    private final String secret,packageName,certificate,project;
    public WelcomeCreditService(JdbcTemplate jdbc,CreditWalletService credits,RestTemplate http,Clock clock,
            PlatformTransactionManager manager,
            @Value("${CREDIT_DEVICE_HMAC_KEY:}") String secret,
            @Value("${PLAY_INTEGRITY_PACKAGE:com.gorkem.ekspersiz}") String packageName,
            @Value("${PLAY_INTEGRITY_CERTIFICATE_SHA256:}") String certificate,
            @Value("${PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER:}") String project) {
        this.jdbc=jdbc;this.credits=credits;this.http=http;this.clock=clock;this.tx=new TransactionTemplate(manager);
        this.secret=secret;this.packageName=packageName;this.certificate=certificate;this.project=project;
    }
    public Map<String,Object> challenge(User user,String deviceId) {
        if (secret.length()<32 || certificate.isBlank() || project.isBlank())
            return Map.of("available",false,"message","Ücretsiz başlangıç kredileri için cihaz doğrulaması şu anda kullanılamıyor.");
        if (deviceId==null || !deviceId.matches("[a-fA-F0-9]{16}")) throw new IllegalArgumentException("Geçersiz cihaz doğrulaması.");
        UUID id=UUID.randomUUID(); String deviceHash=hmac("device:"+deviceId.toLowerCase(Locale.ROOT));
        boolean claimed=Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM credit_welcome_claims WHERE device_hash=? OR identity_hash=? OR account_id=?)",
                Boolean.class,deviceHash,hmac("account:"+user.getEmail().trim().toLowerCase(Locale.ROOT)),"user:"+user.getId()));
        if (claimed) return Map.of("available",false,"message","Bu cihaz veya hesabın başlangıç kredisi hakkı daha önce değerlendirildi.");
        String hash=sha256(id+":"+user.getId()+":"+deviceHash);
        tx.executeWithoutResult(status -> {
            jdbc.execute("SET LOCAL lock_timeout='3s'");
            jdbc.queryForObject("SELECT id FROM users WHERE id=? FOR UPDATE",Long.class,user.getId());
            Long pending=jdbc.queryForObject("SELECT COUNT(*) FROM credit_integrity_challenges WHERE user_id=? AND expires_at>?",Long.class,user.getId(),LocalDateTime.now(clock).plusMinutes(2));
            if (pending!=null && pending>0) throw new IllegalStateException("Cihaz doğrulaması devam ediyor. Bir dakika sonra tekrar deneyebilirsiniz.");
            jdbc.update("DELETE FROM credit_integrity_challenges WHERE user_id=?",user.getId());
            jdbc.update("INSERT INTO credit_integrity_challenges(id,user_id,device_hash,request_hash,expires_at) VALUES (?,?,?,?,?)",id,user.getId(),deviceHash,hash,LocalDateTime.now(clock).plusMinutes(3));
        });
        return Map.of("available",true,"id",id.toString(),"requestHash",hash,"cloudProjectNumber",project);
    }
    public void claim(User user,UUID challengeId,String token) {
        if (secret.length()<32 || certificate.isBlank()) throw new IllegalStateException("Cihaz doğrulaması yapılandırılmadı.");
        var rows=jdbc.queryForList("SELECT * FROM credit_integrity_challenges WHERE id=? AND user_id=? AND NOT used AND expires_at>?",challengeId,user.getId(),LocalDateTime.now(clock));
        if (rows.isEmpty()) throw new IllegalStateException("Cihaz doğrulamasını tekrar deneyin.");
        var challenge=rows.getFirst();
        JsonNode decoded;
        try {
            GoogleCredentials credentials=GoogleCredentials.getApplicationDefault().createScoped("https://www.googleapis.com/auth/playintegrity");
            credentials.refreshIfExpired();
            HttpHeaders headers=new HttpHeaders(); headers.setBearerAuth(credentials.getAccessToken().getTokenValue());
            decoded=http.postForObject("https://playintegrity.googleapis.com/v1/"+packageName+":decodeIntegrityToken",
                    new HttpEntity<>(Map.of("integrity_token",token),headers),JsonNode.class);
        } catch (Exception e) { throw new IllegalStateException("Cihaz doğrulanamadı. Daha sonra tekrar deneyebilirsiniz."); }
        validate(decoded,(String)challenge.get("request_hash"));
        tx.executeWithoutResult(status -> {
            int changed=jdbc.update("UPDATE credit_integrity_challenges SET used=TRUE WHERE id=? AND user_id=? AND NOT used AND expires_at>?",challengeId,user.getId(),LocalDateTime.now(clock));
            if (changed==0) throw new IllegalStateException("Cihaz doğrulaması kullanıldı veya süresi doldu.");
            credits.grantWelcome(user,(String)challenge.get("device_hash"),hmac("account:"+user.getEmail().trim().toLowerCase(Locale.ROOT)));
        });
    }
    void validate(JsonNode decoded,String hash) {
        if (decoded==null) throw new IllegalStateException("Cihaz doğrulanamadı.");
        JsonNode payload=decoded.path("tokenPayloadExternal"),request=payload.path("requestDetails"),app=payload.path("appIntegrity");
        long age=clock.millis()-request.path("timestampMillis").asLong(0);
        boolean cert=false,device=false;
        for (JsonNode value:app.path("certificateSha256Digest")) if(certificate.equals(value.asText())) cert=true;
        for (JsonNode value:payload.path("deviceIntegrity").path("deviceRecognitionVerdict")) if("MEETS_DEVICE_INTEGRITY".equals(value.asText())) device=true;
        if (!hash.equals(request.path("requestHash").asText()) || !packageName.equals(request.path("requestPackageName").asText())
                || !packageName.equals(app.path("packageName").asText()) || !"PLAY_RECOGNIZED".equals(app.path("appRecognitionVerdict").asText())
                || !"LICENSED".equals(payload.path("accountDetails").path("appLicensingVerdict").asText()) || !cert || !device || age<0 || age>180000)
            throw new IllegalStateException("Bu cihaz için ücretsiz kredi uygunluğu doğrulanamadı. Satın aldığınız kredileri kullanabilirsiniz.");
    }
    private String hmac(String value) {
        try { Mac mac=Mac.getInstance("HmacSHA256");mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8),"HmacSHA256"));return HexFormat.of().formatHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8))); }
        catch(Exception e) { throw new IllegalStateException("Cihaz doğrulaması yapılandırılamadı.",e); }
    }
    private static String sha256(String value) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8))); }
        catch(Exception e) { throw new IllegalStateException(e); }
    }
}
