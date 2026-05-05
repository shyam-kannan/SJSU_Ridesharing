-- Add pickup_location column to bookings table
-- This stores the rider's location for pickup (for "To SJSU" trips)

BEGIN;

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS pickup_location JSONB;

-- Add CHECK constraint to validate JSONB structure
-- Ensures pickup_location has required fields: lat, lng, address
ALTER TABLE bookings
  ADD CONSTRAINT check_pickup_location_structure
  CHECK (
    pickup_location IS NULL OR
    (
      jsonb_typeof(pickup_location) = 'object' AND
      (pickup_location ? 'lat') AND
      (pickup_location ? 'lng') AND
      (pickup_location ? 'address') AND
      jsonb_typeof(pickup_location->'lat') = 'number' AND
      jsonb_typeof(pickup_location->'lng') = 'number' AND
      jsonb_typeof(pickup_location->'address') = 'string' AND
      (pickup_location->>'lat')::numeric BETWEEN -90 AND 90 AND
      (pickup_location->>'lng')::numeric BETWEEN -180 AND 180
    )
  );

-- Create GIN index for JSONB queries
CREATE INDEX IF NOT EXISTS idx_bookings_pickup_location ON bookings USING GIN (pickup_location);

COMMENT ON COLUMN bookings.pickup_location IS 'Rider pickup location with {lat, lng, address} - only for To SJSU trips';

COMMIT;
