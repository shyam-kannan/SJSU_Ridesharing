-- Migration 017: Add optional rider-preference max_scost to trip_requests
-- Allows riders to submit a maximum acceptable service cost (He et al. 2014, Section 4.2).
-- NULL means "no ceiling — assign the driver with the lowest Scost regardless of value."

BEGIN;

ALTER TABLE trip_requests
  ADD COLUMN IF NOT EXISTS max_scost NUMERIC DEFAULT NULL;

-- Add CHECK constraint to ensure max_scost is non-negative when provided
ALTER TABLE trip_requests
  ADD CONSTRAINT check_max_scost_non_negative
  CHECK (max_scost IS NULL OR max_scost >= 0);

-- Create index for queries filtering by max_scost
CREATE INDEX IF NOT EXISTS idx_trip_requests_max_scost ON trip_requests(max_scost) WHERE max_scost IS NOT NULL;

COMMENT ON COLUMN trip_requests.max_scost IS 'Maximum acceptable service cost for rider preference (NULL = no limit)';

COMMIT;
