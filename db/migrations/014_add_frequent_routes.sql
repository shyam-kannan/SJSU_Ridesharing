-- Migration 014: Add frequent_routes table for GPS trajectory mining (He et al. 2014)
-- Stores mined frequent routes from completed trip history.
-- Algorithm 1: alpha=2 (qualified edge threshold), gamma=0.8 (qualified route score),
--              beta=2 (frequent edge threshold), iterative convergence.

CREATE TABLE IF NOT EXISTS frequent_routes (
    route_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    origin_zone     INT NOT NULL,           -- 16x16 Bay Area grid cell (0-255)
    destination_zone INT NOT NULL,          -- 16x16 Bay Area grid cell (0-255)
    time_bin        INT NOT NULL,           -- 30-min bucket: 0 (00:00-00:30) … 47 (23:30-00:00)
    frequency       INT NOT NULL DEFAULT 1, -- f(e): how many trips traversed this edge
    edge_score      FLOAT NOT NULL DEFAULT 0.0,  -- Se: normalized edge score
    route_score     FLOAT NOT NULL DEFAULT 0.0,  -- Sr: normalized route score
    last_seen       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_frequent_route UNIQUE (origin_zone, destination_zone, time_bin)
);

CREATE INDEX IF NOT EXISTS idx_frequent_routes_origin  ON frequent_routes (origin_zone);
CREATE INDEX IF NOT EXISTS idx_frequent_routes_dest    ON frequent_routes (destination_zone);
CREATE INDEX IF NOT EXISTS idx_frequent_routes_time    ON frequent_routes (time_bin);
CREATE INDEX IF NOT EXISTS idx_frequent_routes_score   ON frequent_routes (route_score DESC);
