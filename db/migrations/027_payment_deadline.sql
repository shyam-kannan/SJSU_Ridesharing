-- Add payment_deadline_at: set when booking is approved (trip.departure_time - 1 hour)
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_deadline_at TIMESTAMPTZ;

-- Add cancellation_reason for UI messaging
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- Add route_updated_after_cancel flag so the application layer can detect new deadline
-- cancellations and trigger route recalculation + notifications
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS route_updated_after_cancel BOOLEAN DEFAULT FALSE;

-- pg_cron job: every 5 minutes, cancel approved bookings that missed the payment deadline.
-- Matches pattern from 026_fix_expiry_state.sql.
-- Only targets bookings where payment_intent_id IS NULL (payment never authorized) and
-- payment_deadline_at has passed.
SELECT cron.unschedule('cancel-unpaid-approved-bookings');

SELECT cron.schedule(
  'cancel-unpaid-approved-bookings',
  '*/5 * * * *',
  $$
  WITH expired AS (
    SELECT booking_id, trip_id, seats_booked
    FROM bookings
    WHERE booking_state = 'approved'
      AND payment_intent_id IS NULL
      AND payment_deadline_at IS NOT NULL
      AND payment_deadline_at < NOW()
  ),
  cancelled AS (
    UPDATE bookings
    SET
      booking_state       = 'cancelled',
      cancellation_reason = 'payment_not_completed',
      updated_at          = NOW()
    FROM expired
    WHERE bookings.booking_id = expired.booking_id
    RETURNING expired.trip_id, expired.seats_booked
  )
  UPDATE trips
  SET seats_available = seats_available + cancelled.seats_booked
  FROM cancelled
  WHERE trips.trip_id = cancelled.trip_id;
  $$
);
