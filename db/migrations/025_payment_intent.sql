-- Migration 025: Add payment_intent_id and payment_authorized_at to bookings
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_intent_id TEXT;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_authorized_at TIMESTAMPTZ;
