-- Remove database objects left from features that are no longer
-- part of the current application model.
--
-- IF EXISTS is required because fresh databases created from V1
-- already contain the current schema and do not have these legacy objects.

DROP TABLE IF EXISTS rewarded_analysis_sessions;

ALTER TABLE vehicles
DROP COLUMN IF EXISTS conformity_date,
    DROP COLUMN IF EXISTS vehicle_category;

-- Existing databases that were baselined at V1 may be missing this
-- constraint. Fresh databases created by V1 already have it.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'users_subscription_plan_check'
          AND conrelid = 'users'::regclass
    ) THEN
ALTER TABLE users
    ADD CONSTRAINT users_subscription_plan_check
        CHECK (subscription_plan IN ('FREE', 'PLUS', 'PRO', 'BUSINESS'));
END IF;
END
$$;