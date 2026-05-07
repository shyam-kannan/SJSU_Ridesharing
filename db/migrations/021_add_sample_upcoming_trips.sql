-- Migration 021: Add sample upcoming trips for testing Phase 3 iOS Driver Side features
-- This script creates trips with pending bookings for drivers to approve/reject
-- Purpose: Provides test data for driver approval/reject workflow testing

-- Begin transaction for atomic execution
BEGIN;

-- Use CTEs to avoid repeated subqueries and ensure deterministic results
WITH driver_1 AS (
  SELECT user_id FROM users WHERE role = 'Driver' ORDER BY created_at LIMIT 1
),
driver_2 AS (
  SELECT user_id FROM users WHERE role = 'Driver' ORDER BY created_at OFFSET 1 LIMIT 1
),
driver_3 AS (
  SELECT user_id FROM users WHERE role = 'Driver' ORDER BY created_at OFFSET 2 LIMIT 1
),
rider_1 AS (
  SELECT user_id FROM users WHERE role = 'Rider' ORDER BY created_at LIMIT 1
),
rider_2 AS (
  SELECT user_id FROM users WHERE role = 'Rider' ORDER BY created_at OFFSET 1 LIMIT 1
),
rider_3 AS (
  SELECT user_id FROM users WHERE role = 'Rider' ORDER BY created_at OFFSET 2 LIMIT 1
)
-- Insert sample trips for existing drivers
INSERT INTO trips (driver_id, origin, destination, origin_point, destination_point, departure_time, seats_available, max_riders, status, recurrence, featured, created_at, updated_at)
SELECT
  d.user_id,
  t.origin,
  t.destination,
  t.origin_point,
  t.destination_point,
  t.departure_time,
  t.seats_available,
  t.max_riders,
  t.status,
  t.recurrence,
  t.featured,
  t.created_at,
  t.updated_at
FROM (
  -- Trip 1: To SJSU from San Francisco, tomorrow morning, 3 seats
  SELECT
    (SELECT user_id FROM driver_1) as driver_id,
    'San Francisco, CA' as origin,
    'San Jose State University' as destination,
    ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326) as origin_point,
    ST_SetSRID(ST_MakePoint(-121.8811, 37.3352), 4326) as destination_point,
    NOW() + INTERVAL '1 day' + INTERVAL '8 hours' as departure_time,
    3 as seats_available,
    3 as max_riders,
    'pending' as status,
    NULL as recurrence,
    false as featured,
    NOW() as created_at,
    NOW() as updated_at
  UNION ALL
  -- Trip 2: From SJSU to Palo Alto, tomorrow evening, 2 seats
  SELECT
    (SELECT user_id FROM driver_2) as driver_id,
    'San Jose State University' as origin,
    'Palo Alto, CA' as destination,
    ST_SetSRID(ST_MakePoint(-121.8811, 37.3352), 4326) as origin_point,
    ST_SetSRID(ST_MakePoint(-122.1430, 37.4419), 4326) as destination_point,
    NOW() + INTERVAL '1 day' + INTERVAL '17 hours' as departure_time,
    2 as seats_available,
    2 as max_riders,
    'pending' as status,
    NULL as recurrence,
    false as featured,
    NOW() as created_at,
    NOW() as updated_at
  UNION ALL
  -- Trip 3: To SJSU from Fremont, day after tomorrow, 4 seats
  SELECT
    (SELECT user_id FROM driver_1) as driver_id,
    'Fremont, CA' as origin,
    'San Jose State University' as destination,
    ST_SetSRID(ST_MakePoint(-121.9886, 37.5485), 4326) as origin_point,
    ST_SetSRID(ST_MakePoint(-121.8811, 37.3352), 4326) as destination_point,
    NOW() + INTERVAL '2 days' + INTERVAL '9 hours' as departure_time,
    4 as seats_available,
    4 as max_riders,
    'pending' as status,
    'weekdays' as recurrence,
    true as featured,
    NOW() as created_at,
    NOW() as updated_at
  UNION ALL
  -- Trip 4: From SJSU to Santa Clara, 3 days from now, 2 seats
  SELECT
    (SELECT user_id FROM driver_3) as driver_id,
    'San Jose State University' as origin,
    'Santa Clara, CA' as destination,
    ST_SetSRID(ST_MakePoint(-121.8811, 37.3352), 4326) as origin_point,
    ST_SetSRID(ST_MakePoint(-121.9555, 37.3541), 4326) as destination_point,
    NOW() + INTERVAL '3 days' + INTERVAL '16 hours' as departure_time,
    2 as seats_available,
    2 as max_riders,
    'pending' as status,
    NULL as recurrence,
    false as featured,
    NOW() as created_at,
    NOW() as updated_at
  UNION ALL
  -- Trip 5: To SJSU from Milpitas, 4 days from now, 3 seats
  SELECT
    (SELECT user_id FROM driver_1) as driver_id,
    'Milpitas, CA' as origin,
    'San Jose State University' as destination,
    ST_SetSRID(ST_MakePoint(-121.8906, 37.4323), 4326) as origin_point,
    ST_SetSRID(ST_MakePoint(-121.8811, 37.3352), 4326) as destination_point,
    NOW() + INTERVAL '4 days' + INTERVAL '8 hours' as departure_time,
    3 as seats_available,
    3 as max_riders,
    'pending' as status,
    'mon,wed,fri' as recurrence,
    false as featured,
    NOW() as created_at,
    NOW() as updated_at
) t
-- Only insert if trip_id doesn't exist (using ON CONFLICT with no target for idempotency)
ON CONFLICT DO NOTHING;

-- Insert sample pending bookings for the trips
INSERT INTO bookings (trip_id, rider_id, seats_booked, status, booking_state, created_at, updated_at)
SELECT
  t.trip_id,
  (SELECT user_id FROM rider_1),
  1,
  'pending',
  'pending',
  NOW(),
  NOW()
FROM trips t
WHERE t.status = 'pending'
  AND t.departure_time > NOW()
ORDER BY t.departure_time
LIMIT 3
ON CONFLICT DO NOTHING;

-- Insert approved bookings for some trips
INSERT INTO bookings (trip_id, rider_id, seats_booked, status, booking_state, created_at, updated_at)
SELECT
  t.trip_id,
  (SELECT user_id FROM rider_2),
  1,
  'confirmed',
  'approved',
  NOW() - INTERVAL '1 hour',
  NOW()
FROM trips t
WHERE t.status = 'pending'
  AND t.departure_time > NOW()
  AND t.trip_id NOT IN (SELECT trip_id FROM bookings WHERE booking_state = 'pending')
ORDER BY t.departure_time
LIMIT 2
ON CONFLICT DO NOTHING;

-- Insert rejected bookings for some trips
INSERT INTO bookings (trip_id, rider_id, seats_booked, status, booking_state, created_at, updated_at)
SELECT
  t.trip_id,
  (SELECT user_id FROM rider_3),
  1,
  'cancelled',
  'rejected',
  NOW() - INTERVAL '2 hours',
  NOW()
FROM trips t
WHERE t.status = 'pending'
  AND t.departure_time > NOW()
  AND t.trip_id NOT IN (
    SELECT trip_id FROM bookings WHERE booking_state IN ('pending', 'approved')
  )
ORDER BY t.departure_time
LIMIT 1
ON CONFLICT DO NOTHING;

-- Update trip seats_available based on approved bookings
-- Using a more efficient UPDATE with JOIN
UPDATE trips t
SET seats_available = t.max_riders - COALESCE(b.approved_seats, 0)
FROM (
  SELECT
    trip_id,
    SUM(seats_booked) as approved_seats
  FROM bookings
  WHERE booking_state IN ('approved', 'completed')
  GROUP BY trip_id
) b
WHERE t.trip_id = b.trip_id
  AND t.status = 'pending'
  AND t.departure_time > NOW();

-- Commit the transaction
COMMIT;
