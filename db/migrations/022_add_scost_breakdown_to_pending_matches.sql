-- Add Scost breakdown column to pending_matches table
-- This stores the full ML matching algorithm breakdown components:
-- {travel, walk, detour, advance, social, total}
-- The 'score' column already stores the total, but this stores the detailed breakdown

ALTER TABLE pending_matches
ADD COLUMN scost_breakdown JSONB;

-- Add comment for documentation
COMMENT ON COLUMN pending_matches.scost_breakdown IS 'ML matching algorithm breakdown: {travel, walk, detour, advance, social, total}';
