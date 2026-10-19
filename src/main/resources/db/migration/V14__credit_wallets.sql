-- Wallets are serialized by account, including slot checks in the vehicle transaction.
CREATE TABLE credit_accounts (
    id VARCHAR(80) PRIMARY KEY,
    user_id BIGINT UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    business_id BIGINT UNIQUE REFERENCES business_accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE credit_wallets (
    account_id VARCHAR(80) NOT NULL REFERENCES credit_accounts(id),
    resource VARCHAR(16) NOT NULL CHECK (resource IN ('ANALYSIS', 'ASSISTANT', 'SLOT')),
    permanent BIGINT NOT NULL DEFAULT 0 CHECK (permanent >= 0),
    periodic BIGINT NOT NULL DEFAULT 0 CHECK (periodic >= 0),
    debt BIGINT NOT NULL DEFAULT 0 CHECK (debt >= 0),
    period_start TIMESTAMP,
    period_end TIMESTAMP,
    PRIMARY KEY (account_id, resource)
);
CREATE TABLE credit_events (
    event_key VARCHAR(250) PRIMARY KEY,
    account_id VARCHAR(80) NOT NULL REFERENCES credit_accounts(id),
    resource VARCHAR(16) NOT NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(40) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE credit_reservations (
    token UUID PRIMARY KEY,
    account_id VARCHAR(80) NOT NULL REFERENCES credit_accounts(id),
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    resource VARCHAR(16) NOT NULL,
    operation_key VARCHAR(160) NOT NULL,
    request_hash VARCHAR(64) NOT NULL,
    permanent INTEGER NOT NULL,
    periodic INTEGER NOT NULL,
    period_start TIMESTAMP,
    state VARCHAR(16) NOT NULL CHECK (state IN ('RESERVED', 'COMPLETED', 'RELEASED')),
    response_json TEXT,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX credit_operation_once ON credit_reservations(account_id,resource,operation_key) WHERE state<>'RELEASED';
CREATE INDEX credit_reservation_expiry ON credit_reservations(account_id, expires_at) WHERE state = 'RESERVED';
-- Keep numeric audit history, but erase cached answers and request metadata on deletion.
CREATE FUNCTION erase_deleted_credit_response() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.user_id IS NOT NULL AND NEW.user_id IS NULL THEN
        NEW.response_json := NULL;
        NEW.request_hash := repeat('0',64);
        NEW.operation_key := NEW.token::text;
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER credit_response_erasure BEFORE UPDATE OF user_id ON credit_reservations
FOR EACH ROW EXECUTE FUNCTION erase_deleted_credit_response();
CREATE TABLE credit_purchase_intents (
    id UUID PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(120) NOT NULL,
    account_id VARCHAR(80) NOT NULL REFERENCES credit_accounts(id),
    created_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL
);
CREATE INDEX credit_intent_lookup ON credit_purchase_intents(customer_id, product_id, created_at);
-- Transaction tombstones deliberately survive deletion and refund-before-purchase ordering.
CREATE TABLE credit_purchases (
    transaction_id VARCHAR(200) PRIMARY KEY,
    customer_id VARCHAR(36),
    account_id VARCHAR(80) REFERENCES credit_accounts(id),
    product_id VARCHAR(120) NOT NULL,
    resource VARCHAR(16),
    quantity INTEGER NOT NULL DEFAULT 0,
    refunded BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO credit_accounts(id,user_id) SELECT 'user:' || id, id FROM users;
INSERT INTO credit_accounts(id,business_id) SELECT 'business:' || id, id FROM business_accounts;
INSERT INTO credit_wallets(account_id,resource)
SELECT a.id,r.resource FROM credit_accounts a CROSS JOIN (VALUES ('ANALYSIS'),('ASSISTANT'),('SLOT')) r(resource);
UPDATE credit_wallets w SET permanent = GREATEST(0, t.balance)
FROM (SELECT user_id,SUM(amount) balance FROM analysis_credit_transactions GROUP BY user_id) t
WHERE w.account_id = 'user:' || t.user_id AND w.resource = 'ANALYSIS';
INSERT INTO credit_events(event_key,account_id,resource,amount,reason)
SELECT 'migration:' || account_id,account_id,resource,permanent,'LEGACY_BALANCE'
FROM credit_wallets WHERE resource='ANALYSIS' AND permanent>0;
INSERT INTO credit_purchases(transaction_id,customer_id,account_id,product_id,resource,quantity,refunded)
SELECT t.external_transaction_id,u.billing_customer_id,'user:' || t.user_id,t.product_id,'ANALYSIS',t.amount,
 EXISTS (SELECT 1 FROM analysis_credit_transactions r WHERE r.external_transaction_id='refund:' || t.external_transaction_id)
FROM analysis_credit_transactions t JOIN users u ON u.id=t.user_id
WHERE t.amount>0 AND t.external_transaction_id IS NOT NULL;
-- Keep existing vehicles usable. Grandfather capacity, not a recurring free quota.
UPDATE credit_wallets w SET permanent=GREATEST(0,v.total-1)
FROM (SELECT user_id,COUNT(*) total FROM vehicles WHERE NOT archived AND user_id IS NOT NULL GROUP BY user_id) v
WHERE w.account_id='user:' || v.user_id AND w.resource='SLOT';
UPDATE credit_wallets w SET permanent=GREATEST(0,v.total-10)
FROM (SELECT business_account_id,COUNT(*) total FROM vehicles WHERE NOT archived AND business_account_id IS NOT NULL GROUP BY business_account_id) v
WHERE w.account_id='business:' || v.business_account_id AND w.resource='SLOT';

CREATE TABLE credit_welcome_claims (
    device_hash VARCHAR(64) PRIMARY KEY,
    identity_hash VARCHAR(64) UNIQUE,
    account_id VARCHAR(80) NOT NULL UNIQUE REFERENCES credit_accounts(id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Preserve ledger history while allowing account/inspection deletion.
ALTER TABLE analysis_credit_transactions ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE analysis_credit_transactions DROP CONSTRAINT fk_analysis_credit_user;
ALTER TABLE analysis_credit_transactions ADD CONSTRAINT fk_analysis_credit_user
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE analysis_credit_transactions DROP CONSTRAINT fk_analysis_credit_inspection;
ALTER TABLE analysis_credit_transactions ADD CONSTRAINT fk_analysis_credit_inspection
    FOREIGN KEY(inspection_id) REFERENCES damage_inspections(id) ON DELETE SET NULL;

-- Snapshot the remaining paid legacy allowance, so switching code does not reset usage.
UPDATE credit_wallets w SET period_start=u.subscription_started_at,period_end=u.subscription_expires_at,
 periodic=CASE WHEN w.resource='ANALYSIS' THEN GREATEST(0,(CASE u.subscription_plan WHEN 'PRO' THEN 10 ELSE 5 END) -
   (SELECT COUNT(*) FROM analysis_usages a WHERE a.user_id=u.id AND a.started_at>=date_trunc('month',CURRENT_TIMESTAMP)))
 ELSE GREATEST(0,(CASE u.subscription_plan WHEN 'PRO' THEN 5 ELSE 3 END)*
   GREATEST(1,CEIL(EXTRACT(EPOCH FROM (u.subscription_expires_at-CURRENT_TIMESTAMP))/86400))::BIGINT -
   COALESCE((SELECT SUM(d.successful_questions) FROM ai_assistant_daily_usage d WHERE d.user_id=u.id AND d.usage_date=CURRENT_DATE),0)) END
FROM users u WHERE w.account_id='user:' || u.id AND w.resource IN ('ANALYSIS','ASSISTANT')
 AND u.subscription_plan IN ('PLUS','PRO') AND u.subscription_started_at IS NOT NULL AND u.subscription_expires_at>CURRENT_TIMESTAMP;
-- Business analysis usage was tracked against the company. Preserve that usage;
-- the new shared assistant pool starts at 200 (old per-user rows lack company ownership).
UPDATE credit_wallets w SET period_start=u.subscription_started_at,period_end=u.subscription_expires_at,
 periodic=CASE WHEN w.resource='ANALYSIS' THEN GREATEST(0,100 -
   (SELECT COUNT(*) FROM analysis_usages a WHERE a.business_account_id=m.business_account_id
      AND a.started_at>=date_trunc('month',CURRENT_TIMESTAMP))) ELSE 200 END
FROM business_members m JOIN users u ON u.id=m.user_id
WHERE m.role='OWNER' AND w.account_id='business:' || m.business_account_id
 AND w.resource IN ('ANALYSIS','ASSISTANT') AND u.subscription_plan='BUSINESS'
 AND u.subscription_started_at IS NOT NULL AND u.subscription_expires_at>CURRENT_TIMESTAMP;
INSERT INTO credit_events(event_key,account_id,resource,amount,reason)
SELECT 'period:' || account_id || ':' || resource || ':' || to_char(period_start,'YYYY-MM-DD"T"HH24:MI:SS.US'),account_id,resource,periodic,'LEGACY_PERIOD'
FROM credit_wallets WHERE period_start IS NOT NULL;

CREATE TABLE credit_integrity_challenges (
    id UUID PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_hash VARCHAR(64) NOT NULL,
    request_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX credit_challenge_user ON credit_integrity_challenges(user_id);

ALTER TABLE damage_inspections ADD COLUMN report_attempt UUID, ADD COLUMN report_started_at TIMESTAMP;
