-- Migration 018: Add MPG to users table for fuel-cost-based trip settlement
-- Used by the cost-calculation-service to compute mileage-based driver earnings.
-- Default of 25.0 MPG is a reasonable average for passenger vehicles.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS mpg DECIMAL(5,2) DEFAULT 25.00;

COMMENT ON COLUMN users.mpg IS 'Vehicle fuel efficiency in miles per gallon';
