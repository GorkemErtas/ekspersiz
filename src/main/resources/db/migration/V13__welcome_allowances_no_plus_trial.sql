-- Existing accounts receive no retroactive welcome grant. New User entities start with 2/3.
-- Keep the old trial columns for safe rolling deployments and historical data.
ALTER TABLE users
    ADD COLUMN welcome_analysis_remaining INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN welcome_assistant_remaining INTEGER NOT NULL DEFAULT 0;

ALTER TABLE users
    ADD CONSTRAINT chk_user_welcome_analysis_remaining
        CHECK (welcome_analysis_remaining BETWEEN 0 AND 2),
    ADD CONSTRAINT chk_user_welcome_assistant_remaining
        CHECK (welcome_assistant_remaining BETWEEN 0 AND 3);
