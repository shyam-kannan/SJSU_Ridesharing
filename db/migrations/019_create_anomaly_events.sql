-- Create anomaly_events table for tracking route and speed deviations
CREATE TABLE IF NOT EXISTS anomaly_events (
  anomaly_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL CHECK (type IN ('route_deviation', 'speed_anomaly')),
  detected_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
  location geography(POINT, 4326) NOT NULL,
  acknowledged BOOLEAN NOT NULL DEFAULT false,
  acknowledged_at TIMESTAMP
);

-- Indexes for fast queries
CREATE INDEX idx_anomaly_events_trip_id ON anomaly_events(trip_id);
CREATE INDEX idx_anomaly_events_type ON anomaly_events(type);

COMMENT ON TABLE anomaly_events IS 'Stores real-time safety anomaly events such as route deviations and speed anomalies.';
