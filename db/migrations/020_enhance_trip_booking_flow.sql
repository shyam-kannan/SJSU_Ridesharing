-- Migration: Enhance trip and booking tables for posted rides model
-- Version: 020
-- Description: Add featured, max_riders to trips table and booking_state to bookings table

-- Begin transaction for atomic execution
BEGIN;

-- Create ENUM type for booking state (consistent with other status columns)
CREATE TYPE booking_state AS ENUM (
  'pending',    -- Booking created, waiting for driver approval
  'approved',   -- Driver approved the booking
  'rejected',   -- Driver rejected the booking
  'cancelled',  -- Booking was cancelled
  'completed'   -- Trip completed successfully
);

-- Add featured flag to trips table
ALTER TABLE trips ADD COLUMN IF NOT EXISTS featured BOOLEAN DEFAULT false;

-- Add max_riders to trips table (limit concurrent bookings per trip)
-- Note: Default uses seats_available value at time of column addition
ALTER TABLE trips ADD COLUMN IF NOT EXISTS max_riders INTEGER DEFAULT seats_available;

-- Add booking_state to bookings table to track driver approval flow
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS booking_state booking_state DEFAULT 'pending';

-- Create indexes for fast filtering
CREATE INDEX IF NOT EXISTS idx_bookings_booking_state ON bookings(booking_state);
CREATE INDEX IF NOT EXISTS idx_trips_featured ON trips(featured) WHERE featured = true;
CREATE INDEX IF NOT EXISTS idx_trips_max_riders ON trips(max_riders);

-- Update existing bookings to have appropriate booking_state
-- Existing confirmed bookings should be 'approved', pending should stay 'pending'
UPDATE bookings SET booking_state = 'approved' WHERE status = 'confirmed';
UPDATE bookings SET booking_state = 'cancelled' WHERE status = 'cancelled';
UPDATE bookings SET booking_state = 'completed' WHERE status = 'completed';

-- Add comments to document the new columns
COMMENT ON TYPE booking_state IS 'Booking state for driver approval flow: pending, approved, rejected, cancelled, completed';
COMMENT ON COLUMN trips.featured IS 'Flag for drivers to promote certain routes for visibility';
COMMENT ON COLUMN trips.max_riders IS 'Maximum number of riders allowed per trip';
COMMENT ON COLUMN bookings.booking_state IS 'Current state of the booking in the approval workflow';

-- Commit the transaction
COMMIT;
