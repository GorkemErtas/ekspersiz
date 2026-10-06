CREATE TABLE ai_assistant_quota_reservations (
    id UUID PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    status VARCHAR(16) NOT NULL,
    expires_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL,
    created_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL,
    completed_at TIMESTAMP(6) WITHOUT TIME ZONE,
    released_at TIMESTAMP(6) WITHOUT TIME ZONE,
    CONSTRAINT chk_ai_assistant_quota_reservation_status
        CHECK (status IN ('RESERVED', 'COMPLETED', 'RELEASED'))
);

CREATE INDEX idx_ai_assistant_quota_reservation_active
    ON ai_assistant_quota_reservations(user_id, usage_date, expires_at)
    WHERE status = 'RESERVED';

ALTER TABLE ai_assistant_daily_usage
    DROP COLUMN reserved_questions;
