-- Add Scost breakdown column to bookings table
-- This stores the ML matching algorithm breakdown components:
-- {travel, walk, detour, advance, social, total}
-- Each component represents a different cost factor in the matching algorithm

ALTER TABLE bookings
ADD COLUMN scost_breakdown JSONB;

-- Add comment for documentation
COMMENT ON COLUMN bookings.scost_breakdown IS 'ML matching algorithm breakdown: {travel, walk, detour, advance, social, total}';
