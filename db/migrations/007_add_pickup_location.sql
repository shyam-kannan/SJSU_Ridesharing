-- Add pickup_location column to bookings table
-- This stores the rider's location for pickup (for "To SJSU" trips)

ALTER TABLE bookings
ADD COLUMN pickup_location JSONB;

COMMENT ON COLUMN bookings.pickup_location IS 'Rider pickup location with {lat, lng, address} - only for To SJSU trips';
