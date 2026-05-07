-- Migration: Add partial unique index to prevent duplicate active bookings per rider per trip
-- Version: 023

BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_booking_trip_rider
  ON bookings (trip_id, rider_id)
  WHERE booking_state NOT IN ('cancelled', 'rejected');

COMMIT;
