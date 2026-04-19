-- Migration 017: add optional rider-preference max_scost to trip_requests
-- Allows riders to submit a maximum acceptable service cost (He et al. 2014, Section 4.2).
-- NULL means "no ceiling — assign the driver with the lowest Scost regardless of value."
ALTER TABLE trip_requests
  ADD COLUMN IF NOT EXISTS max_scost NUMERIC DEFAULT NULL;
