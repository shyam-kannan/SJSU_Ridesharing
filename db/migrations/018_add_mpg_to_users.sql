-- Migration 018: Add MPG to users table for fuel-cost-based trip settlement
-- Used by the cost-calculation-service to compute mileage-based driver earnings.
-- Default of 25.0 MPG is a reasonable average for passenger vehicles.

BEGIN;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS mpg DECIMAL(5,2) DEFAULT 25.00;

-- Add CHECK constraint for reasonable MPG values (5-100 MPG)
ALTER TABLE users
  ADD CONSTRAINT check_mpg_range
  CHECK (mpg IS NULL OR (mpg >= 5.0 AND mpg <= 100.0));

-- Create index for queries filtering by MPG (useful for cost calculations)
CREATE INDEX IF NOT EXISTS idx_users_mpg ON users(mpg) WHERE mpg IS NOT NULL;

COMMENT ON COLUMN users.mpg IS 'Vehicle fuel efficiency in miles per gallon (range: 5-100)';

COMMIT;
