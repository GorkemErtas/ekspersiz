-- Adds optional source metadata for server-calculated vehicle reminders.
-- Existing reminders and vehicles remain valid because every new column is nullable.

ALTER TABLE vehicles
    ADD COLUMN IF NOT EXISTS vehicle_category VARCHAR(40),
    ADD COLUMN IF NOT EXISTS conformity_date DATE;

ALTER TABLE vehicle_reminders
    ADD COLUMN IF NOT EXISTS source_date DATE,
    ADD COLUMN IF NOT EXISTS source_mileage INTEGER,
    ADD COLUMN IF NOT EXISTS interval_months INTEGER,
    ADD COLUMN IF NOT EXISTS interval_mileage INTEGER,
    ADD COLUMN IF NOT EXISTS first_inspection BOOLEAN;

ALTER TABLE maintenance_records
    ADD COLUMN IF NOT EXISTS interval_months INTEGER,
    ADD COLUMN IF NOT EXISTS interval_mileage INTEGER;
