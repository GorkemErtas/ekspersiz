-- Existing companies and balances stay production. Only newly confirmed test-company creation sets this flag.
ALTER TABLE business_accounts ADD COLUMN sandbox BOOLEAN NOT NULL DEFAULT FALSE;

-- Sandbox delivery limits scan only the explicitly classified test ledger, never historic/real purchases.
CREATE INDEX credit_sandbox_customer_budget ON credit_purchases(customer_id, resource) WHERE environment='SANDBOX';

-- Protect the environment boundary even from accidental application updates.
CREATE FUNCTION preserve_business_environment() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.sandbox IS DISTINCT FROM OLD.sandbox THEN
        RAISE EXCEPTION 'Business purchase environment is immutable';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER business_environment_immutable BEFORE UPDATE OF sandbox ON business_accounts
FOR EACH ROW EXECUTE FUNCTION preserve_business_environment();
