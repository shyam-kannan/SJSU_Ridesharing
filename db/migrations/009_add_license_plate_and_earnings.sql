-- Add license_plate and earnings to users table
-- License plate for driver vehicle identification
-- Earnings to track driver income

ALTER TABLE users
ADD COLUMN license_plate VARCHAR(20),
ADD COLUMN earnings DECIMAL(10,2) DEFAULT 0.00;

COMMENT ON COLUMN users.license_plate IS 'Driver vehicle license plate';
COMMENT ON COLUMN users.earnings IS 'Total earnings for drivers in USD';

CREATE INDEX idx_users_license_plate ON users(license_plate) WHERE license_plate IS NOT NULL;
