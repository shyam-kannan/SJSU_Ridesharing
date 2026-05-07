-- Create messages table for rider-driver chat

BEGIN;

CREATE TABLE IF NOT EXISTS messages (
  message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  message_text TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
  read_at TIMESTAMP,
  -- CHECK constraint for message length
  CONSTRAINT check_message_length CHECK (LENGTH(TRIM(message_text)) > 0 AND LENGTH(message_text) <= 5000)
);

-- Indexes for fast queries
CREATE INDEX idx_messages_trip ON messages(trip_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_created ON messages(created_at DESC);
CREATE INDEX idx_messages_trip_created ON messages(trip_id, created_at DESC);
-- Composite index for fetching messages between specific users on a trip
CREATE INDEX idx_messages_trip_sender ON messages(trip_id, sender_id);

COMMENT ON TABLE messages IS 'Chat messages between riders and drivers for specific trips';
COMMENT ON COLUMN messages.message_text IS 'Message content (max 5000 characters)';
COMMENT ON COLUMN messages.read_at IS 'Timestamp when message was read by recipient';

COMMIT;
