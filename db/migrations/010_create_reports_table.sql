-- Reports table for user safety/behavior reporting
-- Allows users to report issues with other users

CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'resolved');
CREATE TYPE report_category AS ENUM (
  'safety_concern',
  'inappropriate_behavior',
  'cleanliness',
  'harassment',
  'discrimination',
  'route_issue',
  'payment_dispute',
  'no_show',
  'other'
);

CREATE TABLE reports (
  report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  trip_id UUID REFERENCES trips(trip_id) ON DELETE SET NULL,
  category report_category NOT NULL,
  description TEXT NOT NULL,
  status report_status NOT NULL DEFAULT 'pending',
  admin_notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT current_timestamp,
  updated_at TIMESTAMP NOT NULL DEFAULT current_timestamp
);

CREATE INDEX idx_reports_reporter ON reports(reporter_id);
CREATE INDEX idx_reports_reported_user ON reports(reported_user_id);
CREATE INDEX idx_reports_trip ON reports(trip_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);

CREATE TRIGGER update_reports_updated_at
BEFORE UPDATE ON reports
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE reports IS 'User reports for safety, behavior, and other issues';
