-- Enable pg_cron extension for scheduled job support
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

-- Register job to expire pending bookings with elapsed hold_expires_at every 5 minutes
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
