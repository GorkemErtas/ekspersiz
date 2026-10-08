CREATE TABLE ai_assistant_business_daily_usage (
    business_account_id BIGINT NOT NULL REFERENCES business_accounts(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    successful_questions INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(6) WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (business_account_id, usage_date),
    CONSTRAINT chk_business_assistant_questions_nonnegative CHECK (successful_questions >= 0)
);

ALTER TABLE ai_assistant_quota_reservations
    ADD COLUMN business_account_id BIGINT REFERENCES business_accounts(id) ON DELETE CASCADE;

CREATE INDEX idx_ai_assistant_business_reservations
    ON ai_assistant_quota_reservations(business_account_id, usage_date, expires_at)
    WHERE status = 'RESERVED';
