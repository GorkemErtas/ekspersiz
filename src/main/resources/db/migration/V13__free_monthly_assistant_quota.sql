ALTER TABLE ai_assistant_quota_reservations
    ADD COLUMN quota_period VARCHAR(16) NOT NULL DEFAULT 'DAILY';

ALTER TABLE ai_assistant_quota_reservations
    ADD CONSTRAINT chk_ai_assistant_reservation_quota_period
    CHECK (quota_period IN ('DAILY', 'FREE_MONTHLY'));

CREATE INDEX idx_ai_assistant_free_monthly_quota
    ON ai_assistant_quota_reservations(user_id, usage_date, status)
    WHERE quota_period = 'FREE_MONTHLY';
