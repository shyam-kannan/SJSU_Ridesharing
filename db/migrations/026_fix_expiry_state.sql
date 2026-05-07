-- Update pg_cron expiry job: set booking_state to 'cancelled' (not 'rejected')
-- on timeout, so riders see "Driver didn't respond" rather than "Declined".
SELECT cron.unschedule('expire-pending-bookings');

SELECT cron.schedule(
  'expire-pending-bookings',
  '*/5 * * * *',
  $$
  WITH expired AS (
    SELECT booking_id, trip_id, seats_booked
    FROM bookings
    WHERE booking_state = 'pending'
      AND hold_expires_at IS NOT NULL
      AND hold_expires_at < NOW()
  ),
  cancelled AS (
    UPDATE bookings
    SET booking_state = 'cancelled'
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
