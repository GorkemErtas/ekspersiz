-- Additive only: existing sessions remain valid until credentials change.
ALTER TABLE users ADD COLUMN auth_version BIGINT NOT NULL DEFAULT 0;

-- Shared across replicas; no raw email addresses, passwords or codes are stored.
CREATE TABLE authentication_rate_limits (
    bucket_key VARCHAR(100) PRIMARY KEY,
    attempts INTEGER NOT NULL CHECK (attempts > 0),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX idx_authentication_rate_limits_expiry ON authentication_rate_limits (expires_at);
