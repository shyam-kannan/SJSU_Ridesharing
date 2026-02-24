-- Add enhanced trip states for real-time ride tracking
-- States: pending, en_route, arrived, in_progress, completed, cancelled

-- First, convert column to VARCHAR to allow manipulation
ALTER TABLE trips
  ALTER COLUMN status TYPE VARCHAR(20);

-- Update existing values to match new enum
UPDATE trips SET status = 'pending' WHERE status = 'active';
-- 'completed' and 'cancelled' already match new enum

-- Drop old enum type
DROP TYPE IF EXISTS trip_status CASCADE;

-- Create new enum with enhanced states
CREATE TYPE trip_status AS ENUM (
  'pending',      -- Trip created, waiting for driver to start
  'en_route',     -- Driver heading to pickup location
  'arrived',      -- Driver at pickup location
  'in_progress',  -- Rider in car, heading to destination
  'completed',    -- Trip finished
  'cancelled'     -- Trip cancelled
);

-- Convert trips table to use new enum
ALTER TABLE trips
  ALTER COLUMN status TYPE trip_status USING status::trip_status;

-- Set default to 'pending' for new trips
ALTER TABLE trips
  ALTER COLUMN status SET DEFAULT 'pending';

-- Add timestamps for state transitions
ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS pickup_completed_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;

COMMENT ON COLUMN trips.started_at IS 'When driver started heading to pickup';
COMMENT ON COLUMN trips.arrived_at IS 'When driver arrived at pickup location';
COMMENT ON COLUMN trips.pickup_completed_at IS 'When rider got in car';
COMMENT ON COLUMN trips.completed_at IS 'When trip was completed';

-- Create index for querying active trips
CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_driver_status ON trips(driver_id, status);
