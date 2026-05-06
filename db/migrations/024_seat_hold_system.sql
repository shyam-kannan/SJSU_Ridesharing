-- Migration: Seat hold system — hold_expires_at, soft-delete columns, and pg_cron expiry job
-- Version: 024

BEGIN;

-- 1. Add hold_expires_at to bookings (nullable)
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS hold_expires_at TIMESTAMPTZ;

-- 2. Add soft-delete column to bookings (nullable)
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 3. Add soft-delete column to trips (nullable)
ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 4. Backfill hold_expires_at for existing pending bookings
UPDATE bookings
SET hold_expires_at = created_at + INTERVAL '2 hours'
WHERE booking_state = 'pending'
  AND hold_expires_at IS NULL;

COMMIT;

-- 5. Register pg_cron job to expire pending bookings every 5 minutes
--    (runs outside transaction block — pg_cron requires superuser context)
SELECT cron.schedule(
  'expire-pending-bookings',
  '*/5 * * * *',
  $$
  WITH expired AS (
    SELECT booking_id, trip_id, seats_booked
    FROM bookings
    WHERE booking_state = 'pending'
      AND hold_expires_at < NOW()
  ),
  rejected AS (
    UPDATE bookings
    SET booking_state = 'rejected'
    FROM expired
    WHERE bookings.booking_id = expired.booking_id
    RETURNING expired.trip_id, expired.seats_booked
  )
  UPDATE trips
  SET seats_available = seats_available + rejected.seats_booked
  FROM rejected
  WHERE trips.trip_id = rejected.trip_id;
  $$
);
