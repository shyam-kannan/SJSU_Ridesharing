-- Add license_plate and earnings to users table
-- License plate for driver vehicle identification
-- Earnings to track driver income

BEGIN;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS license_plate VARCHAR(20),
  ADD COLUMN IF NOT EXISTS earnings DECIMAL(10,2) DEFAULT 0.00;

-- Add CHECK constraint for earnings (must be non-negative)
ALTER TABLE users
  ADD CONSTRAINT check_earnings_non_negative
  CHECK (earnings IS NULL OR earnings >= 0);

-- Add CHECK constraint for license plate format (alphanumeric, 6-8 characters)
-- This is a basic validation; actual format may vary by jurisdiction
ALTER TABLE users
  ADD CONSTRAINT check_license_plate_format
  CHECK (
    license_plate IS NULL OR
    (license_plate ~ '^[A-Z0-9]{6,8}$' OR license_plate ~ '^[A-Z0-9-]{6,10}$')
  );

COMMENT ON COLUMN users.license_plate IS 'Driver vehicle license plate (alphanumeric, 6-10 chars)';
COMMENT ON COLUMN users.earnings IS 'Total earnings for drivers in USD (non-negative)';

CREATE INDEX idx_users_license_plate ON users(license_plate) WHERE license_plate IS NOT NULL;

COMMIT;
