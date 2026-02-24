-- Create trip_locations table for real-time driver location tracking

CREATE TABLE IF NOT EXISTS trip_locations (
  location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  location geography(POINT, 4326) NOT NULL,
  heading DECIMAL(5,2), -- Direction in degrees (0-360)
  speed DECIMAL(6,2),    -- Speed in km/h
  accuracy DECIMAL(6,2), -- Location accuracy in meters
  created_at TIMESTAMP NOT NULL DEFAULT current_timestamp
);

-- Indexes for fast queries
CREATE INDEX idx_trip_locations_trip ON trip_locations(trip_id);
CREATE INDEX idx_trip_locations_driver ON trip_locations(driver_id);
CREATE INDEX idx_trip_locations_created ON trip_locations(created_at DESC);

-- Spatial index for location queries
CREATE INDEX idx_trip_locations_location ON trip_locations USING GIST(location);

-- Auto-delete old locations (keep only last 24 hours)
-- This can be run as a cron job or trigger
COMMENT ON TABLE trip_locations IS 'Stores driver location updates during active trips. Old records should be cleaned up regularly.';
