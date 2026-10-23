-- Historic rows did not record environment. Preserve them and their balances;
-- never guess that they were production or grant them again during sandbox replay.
ALTER TABLE credit_purchases ADD COLUMN environment VARCHAR(16) NOT NULL DEFAULT 'LEGACY'
    CHECK (environment IN ('LEGACY', 'PRODUCTION', 'SANDBOX'));
ALTER TABLE credit_purchases DROP CONSTRAINT credit_purchases_pkey;
ALTER TABLE credit_purchases ADD PRIMARY KEY (transaction_id, environment);

ALTER TABLE billing_webhook_events ADD COLUMN environment VARCHAR(16) NOT NULL DEFAULT 'LEGACY'
    CHECK (environment IN ('LEGACY', 'PRODUCTION', 'SANDBOX', 'CONTROL'));
ALTER TABLE billing_webhook_events DROP CONSTRAINT uk_billing_webhook_event_provider_id;
ALTER TABLE billing_webhook_events ADD CONSTRAINT uk_billing_webhook_event_provider_id
    UNIQUE (provider_event_id, environment);
