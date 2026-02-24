-- Add profile_picture_url column to users table
-- Stores the URL/path to user's uploaded profile picture

ALTER TABLE users
ADD COLUMN profile_picture_url VARCHAR(500);

COMMENT ON COLUMN users.profile_picture_url IS 'URL or path to user profile picture - format: /uploads/profile-pictures/{userId}.jpg';
