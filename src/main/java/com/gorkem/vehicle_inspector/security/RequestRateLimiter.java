package com.gorkem.vehicle_inspector.security;

import com.gorkem.vehicle_inspector.exception.RateLimitExceededException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicLong;

/** Account limits persist across failures, process restarts and replicas. */
@Service
public class RequestRateLimiter {
    public enum Action {
        LOGIN(20), VERIFICATION_SEND(3), VERIFICATION_CHECK(5),
        RESET_SEND(3), RESET_CHECK(5), PASSWORD_CHANGE(10),
        INVITATION_SEND(10), INVITATION_CHECK(5),
        AI_CHAT(60), IMAGE_QUALITY(30), NEARBY_SEARCH(20), BILLING_SYNC(30), PHOTO_UPLOAD(30);

        private final int limit;
        Action(int limit) { this.limit = limit; }
    }

    private final JdbcTemplate jdbc;
    private final AtomicLong nextCleanup = new AtomicLong();

    public RequestRateLimiter(JdbcTemplate jdbc) { this.jdbc = jdbc; }

    // Called by controllers before any business transaction. A rejected or failed
    // login/reset must not roll back the budget consumed by previous attempts.
    @Transactional(propagation = Propagation.REQUIRES_NEW,
            noRollbackFor = RateLimitExceededException.class)
    public void check(Action action, String identity) {
        String key = action.name() + ":" + hash(identity);
        var accepted = jdbc.queryForList("""
                INSERT INTO authentication_rate_limits(bucket_key, attempts, expires_at)
                VALUES (?, 1, CURRENT_TIMESTAMP + INTERVAL '15 minutes')
                ON CONFLICT (bucket_key) DO UPDATE SET
                    attempts = CASE WHEN authentication_rate_limits.expires_at <= CURRENT_TIMESTAMP
                        THEN 1 ELSE authentication_rate_limits.attempts + 1 END,
                    expires_at = CASE WHEN authentication_rate_limits.expires_at <= CURRENT_TIMESTAMP
                        THEN CURRENT_TIMESTAMP + INTERVAL '15 minutes'
                        ELSE authentication_rate_limits.expires_at END
                WHERE authentication_rate_limits.expires_at <= CURRENT_TIMESTAMP
                    OR authentication_rate_limits.attempts < ?
                RETURNING attempts
                """, key, action.limit);
        if (accepted.isEmpty()) {
            Long retry = jdbc.queryForObject("""
                    SELECT GREATEST(1, CEIL(EXTRACT(EPOCH FROM (expires_at - CURRENT_TIMESTAMP))))::bigint
                    FROM authentication_rate_limits WHERE bucket_key = ?
                    """, Long.class, key);
            throw new RateLimitExceededException(retry == null ? 900 : retry);
        }
        long now = System.currentTimeMillis();
        long next = nextCleanup.get();
        if (now >= next && nextCleanup.compareAndSet(next, now + 60_000)) {
            jdbc.update("""
                    DELETE FROM authentication_rate_limits WHERE bucket_key IN
                        (SELECT bucket_key FROM authentication_rate_limits
                         WHERE expires_at < CURRENT_TIMESTAMP ORDER BY expires_at LIMIT 1000 FOR UPDATE SKIP LOCKED)
                    """);
        }
    }

    private String hash(String identity) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(
                    identity.trim().toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException(impossible);
        }
    }
}
