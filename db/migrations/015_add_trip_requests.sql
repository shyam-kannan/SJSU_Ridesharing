-- Migration 015: Rider trip requests and driver pending matches
-- trip_requests: a rider's one-shot request for a ride (posted before any driver is assigned).
-- pending_matches: driver candidates surfaced by the matching pipeline; 15-second acceptance window.

CREATE TABLE IF NOT EXISTS trip_requests (
    request_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id        UUID NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
    origin          TEXT NOT NULL,
    destination     TEXT NOT NULL,
    origin_lat      DOUBLE PRECISION NOT NULL,
    origin_lng      DOUBLE PRECISION NOT NULL,
    destination_lat DOUBLE PRECISION NOT NULL,
    destination_lng DOUBLE PRECISION NOT NULL,
    origin_point    GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS
                        (ST_SetSRID(ST_MakePoint(origin_lng, origin_lat), 4326)::geography) STORED,
    destination_point GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS
                        (ST_SetSRID(ST_MakePoint(destination_lng, destination_lat), 4326)::geography) STORED,
    departure_time  TIMESTAMPTZ NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'matched', 'expired', 'cancelled')),
    matched_trip_id UUID REFERENCES trips (trip_id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trip_requests_rider   ON trip_requests (rider_id);
CREATE INDEX IF NOT EXISTS idx_trip_requests_status  ON trip_requests (status);
CREATE INDEX IF NOT EXISTS idx_trip_requests_origin  ON trip_requests USING GIST (origin_point);

-- pending_matches: one row per (request, driver-trip) candidate.
-- Expires 15 seconds after creation; driver must accept within that window.
CREATE TABLE IF NOT EXISTS pending_matches (
    match_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id  UUID NOT NULL REFERENCES trip_requests (request_id) ON DELETE CASCADE,
    trip_id     UUID NOT NULL REFERENCES trips (trip_id)           ON DELETE CASCADE,
    driver_id   UUID NOT NULL REFERENCES users (user_id)           ON DELETE CASCADE,
    score       FLOAT  NOT NULL DEFAULT 0.0,   -- Scost from He et al. eq 9
    attempt     INT    NOT NULL DEFAULT 1,     -- retry counter (max 5)
    status      VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'accepted', 'declined', 'expired')),
    expires_at  TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '15 seconds'),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pending_matches_request  ON pending_matches (request_id);
CREATE INDEX IF NOT EXISTS idx_pending_matches_driver   ON pending_matches (driver_id);
CREATE INDEX IF NOT EXISTS idx_pending_matches_status   ON pending_matches (status);
CREATE INDEX IF NOT EXISTS idx_pending_matches_expires  ON pending_matches (expires_at);
