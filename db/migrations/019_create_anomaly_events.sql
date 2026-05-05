-- Migration 019: Create anomaly_events table for tracking route and speed deviations
-- This table stores real-time safety anomaly events such as route deviations and speed anomalies
-- Used by the safety monitoring system to alert drivers and riders of potential issues

BEGIN;

-- PostGIS extension should already be enabled, but ensure it's available
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS anomaly_events (
  anomaly_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL CHECK (type IN ('route_deviation', 'speed_anomaly', 'unauthorized_stop', 'long_stop')),
  detected_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
  location geography(POINT, 4326) NOT NULL,
  acknowledged BOOLEAN NOT NULL DEFAULT false,
  acknowledged_at TIMESTAMP,
  -- Additional metadata for anomaly details
  metadata JSONB DEFAULT '{}'::jsonb,
  -- CHECK constraint for timestamp ordering
  CONSTRAINT check_anomaly_acknowledgment_timing
    CHECK (acknowledged IS FALSE OR acknowledged_at IS NOT NULL)
);

-- Indexes for fast queries
CREATE INDEX idx_anomaly_events_trip_id ON anomaly_events(trip_id);
CREATE INDEX idx_anomaly_events_type ON anomaly_events(type);
CREATE INDEX idx_anomaly_events_acknowledged ON anomaly_events(acknowledged) WHERE acknowledged = false;
CREATE INDEX idx_anomaly_events_detected_at ON anomaly_events(detected_at DESC);
-- Composite index for unacknowledged anomalies by trip
CREATE INDEX idx_anomaly_events_trip_unacknowledged ON anomaly_events(trip_id, acknowledged) WHERE acknowledged = false;
-- GIN index for metadata JSONB queries
CREATE INDEX idx_anomaly_events_metadata ON anomaly_events USING GIN (metadata);

COMMENT ON TABLE anomaly_events IS 'Stores real-time safety anomaly events such as route deviations, speed anomalies, unauthorized stops, and long stops';
COMMENT ON COLUMN anomaly_events.type IS 'Type of anomaly: route_deviation, speed_anomaly, unauthorized_stop, long_stop';
COMMENT ON COLUMN anomaly_events.location IS 'Geographic location where anomaly was detected';
COMMENT ON COLUMN anomaly_events.metadata IS 'Additional details about the anomaly (e.g., severity, duration, distance)';

COMMIT;
