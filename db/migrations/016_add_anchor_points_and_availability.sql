-- Migration 016: Anchor points for multi-passenger route merging + driver availability flag
-- anchor_points: ordered waypoints produced by He et al. Algorithm 3 route merging.
-- available_for_rides: driver opt-in flag for the on-demand matching flow.

BEGIN;

-- Add anchor points column to trips (Algorithm 3 incremental merge output)
ALTER TABLE trips
    ADD COLUMN IF NOT EXISTS anchor_points JSONB DEFAULT '[]'::jsonb;

-- Add driver availability toggle for on-demand matching
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS available_for_rides BOOLEAN NOT NULL DEFAULT false;

-- Index for fast lookup of available drivers (partial index for efficiency)
CREATE INDEX IF NOT EXISTS idx_users_available ON users (available_for_rides)
    WHERE available_for_rides = true;

-- Index for anchor point queries (trips that have computed anchors)
-- GIN index enables efficient JSONB containment and path queries
CREATE INDEX IF NOT EXISTS idx_trips_anchor_points ON trips
    USING GIN (anchor_points)
    WHERE anchor_points IS NOT NULL AND anchor_points != '[]'::jsonb;

COMMENT ON COLUMN trips.anchor_points IS 'Ordered waypoints from route merging algorithm (He et al. Algorithm 3)';
COMMENT ON COLUMN users.available_for_rides IS 'Driver opt-in flag for on-demand matching flow';

COMMIT;
