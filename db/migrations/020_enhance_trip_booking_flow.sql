-- Migration: Enhance trip and booking tables for posted rides model
-- Version: 020
-- Description: Add featured, max_riders to trips table and booking_state to bookings table

-- Add featured flag to trips table
ALTER TABLE trips ADD COLUMN featured BOOLEAN DEFAULT false;

-- Add max_riders to trips table (limit concurrent bookings per trip)
ALTER TABLE trips ADD COLUMN max_riders INTEGER DEFAULT seats_available;

-- Add booking_state to bookings table to track driver approval flow
ALTER TABLE bookings ADD COLUMN booking_state VARCHAR(20) DEFAULT 'pending';

-- Create index on booking_state for fast filtering
CREATE INDEX idx_bookings_booking_state ON bookings(booking_state);

-- Update existing bookings to have appropriate booking_state
-- Existing confirmed bookings should be 'approved', pending should stay 'pending'
UPDATE bookings SET booking_state = 'approved' WHERE status = 'confirmed';
UPDATE bookings SET booking_state = 'cancelled' WHERE status = 'cancelled';
UPDATE bookings SET booking_state = 'completed' WHERE status = 'completed';

-- Add comment to document the new columns
COMMENT ON COLUMN trips.featured IS 'Flag for drivers to promote certain routes for visibility';
COMMENT ON COLUMN trips.max_riders IS 'Maximum number of riders allowed per trip';
COMMENT ON COLUMN bookings.booking_state IS 'Booking state for driver approval flow: pending, approved, rejected, cancelled, completed';
