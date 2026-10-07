ALTER TABLE ai_assistant_daily_usage
    ADD COLUMN reserved_questions INTEGER NOT NULL DEFAULT 0;

ALTER TABLE ai_assistant_daily_usage
    ADD CONSTRAINT chk_ai_assistant_reserved_questions
        CHECK (reserved_questions >= 0);
