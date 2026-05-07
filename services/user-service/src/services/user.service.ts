import { Pool } from 'pg';
import { config } from '../config';
import { SafeUser, Rating, RatingWithUsers, DriverSetupRequest, UserRole } from '@lessgo/shared';

const pool = new Pool({
  connectionString: config.databaseUrl,
});

/**
 * Get user profile by ID
 * @param userId User's UUID
 * @returns User profile without password
 */
export const getUserById = async (userId: string): Promise<SafeUser | null> => {
  const query = `
    SELECT user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, license_plate, earnings, mpg, profile_picture_url, created_at, updated_at
    FROM users
    WHERE user_id = $1
  `;

  const result = await pool.query(query, [userId]);

  if (result.rows.length === 0) {
    return null;
  }

  return result.rows[0];
};

/**
 * Update user profile
 * @param userId User's UUID
 * @param updates Profile updates (name, email)
 * @returns Updated user profile
 */
export const updateUserProfile = async (
  userId: string,
  updates: { name?: string; email?: string }
): Promise<SafeUser> => {
  const fields: string[] = [];
  const values: any[] = [];
  let paramIndex = 1;

  if (updates.name) {
    fields.push(`name = $${paramIndex}`);
    values.push(updates.name);
    paramIndex++;
  }

  if (updates.email) {
    fields.push(`email = $${paramIndex}`);
    values.push(updates.email.toLowerCase());
    paramIndex++;
  }

  if (fields.length === 0) {
    throw new Error('No fields to update');
  }

  fields.push(`updated_at = current_timestamp`);
  values.push(userId);

  const query = `
    UPDATE users
    SET ${fields.join(', ')}
    WHERE user_id = $${paramIndex}
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, license_plate, earnings, mpg, profile_picture_url, created_at, updated_at
  `;

  const result = await pool.query(query, values);

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  return result.rows[0];
};

/**
 * Setup driver profile
 * @param userId User's UUID
 * @param driverData Driver information
 * @returns Updated user profile
 */
export const setupDriverProfile = async (
  userId: string,
  driverData: DriverSetupRequest
): Promise<SafeUser> => {
  const { vehicle_info, seats_available, license_plate, mpg } = driverData;

  const query = `
    UPDATE users
    SET
      role = $1,
      vehicle_info = $2,
      seats_available = $3,
      license_plate = $4,
      mpg = $5,
      updated_at = current_timestamp
    WHERE user_id = $6
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, license_plate, earnings, mpg, created_at, updated_at
  `;

  const result = await pool.query(query, [
    UserRole.Driver,
    vehicle_info,
    seats_available,
    license_plate,
    mpg ?? 25.0,
    userId,
  ]);

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  return result.rows[0];
};

/**
 * Get user's ratings (as ratee)
 * @param userId User's UUID
 * @returns Array of ratings with rater information
 */
export const getUserRatings = async (userId: string): Promise<RatingWithUsers[]> => {
  const query = `
    SELECT
      r.rating_id,
      r.booking_id,
      r.rater_id,
      r.ratee_id,
      r.score,
      r.comment,
      r.created_at,
      rater.user_id as rater_user_id,
      rater.name as rater_name,
      rater.email as rater_email,
      rater.role as rater_role,
      rater.sjsu_id_status as rater_sjsu_id_status,
      rater.rating as rater_rating,
      rater.created_at as rater_created_at,
      rater.updated_at as rater_updated_at
    FROM ratings r
    JOIN users rater ON r.rater_id = rater.user_id
    WHERE r.ratee_id = $1
    ORDER BY r.created_at DESC
  `;

  const result = await pool.query(query, [userId]);

  return result.rows.map((row) => ({
    rating_id: row.rating_id,
    booking_id: row.booking_id,
    rater_id: row.rater_id,
    ratee_id: row.ratee_id,
    score: row.score,
    comment: row.comment,
    created_at: row.created_at,
    rater: {
      user_id: row.rater_user_id,
      name: row.rater_name,
      email: row.rater_email,
      role: row.rater_role,
      sjsu_id_status: row.rater_sjsu_id_status,
      rating: row.rater_rating,
      created_at: row.rater_created_at,
      updated_at: row.rater_updated_at,
    },
    ratee: {} as SafeUser, // Not needed since we're viewing our own ratings
  }));
};

/**
 * Calculate and update user's average rating
 * @param userId User's UUID
 * @returns Updated average rating
 */
export const updateUserAverageRating = async (userId: string): Promise<number> => {
  // Calculate average rating
  const avgQuery = `
    SELECT COALESCE(AVG(score), 0) as avg_rating
    FROM ratings
    WHERE ratee_id = $1
  `;

  const avgResult = await pool.query(avgQuery, [userId]);
  const averageRating = parseFloat(avgResult.rows[0].avg_rating);

  // Update user's rating
  const updateQuery = `
    UPDATE users
    SET rating = $1, updated_at = current_timestamp
    WHERE user_id = $2
    RETURNING rating
  `;

  const result = await pool.query(updateQuery, [averageRating, userId]);

  return result.rows[0].rating;
};

/**
 * Get user statistics
 * @param userId User's UUID
 * @returns User statistics
 */
export const getUserStats = async (
  userId: string
): Promise<{
  total_ratings: number;
  average_rating: number;
  total_trips_as_driver?: number;
  total_bookings_as_rider?: number;
}> => {
  // Get user to check role
  const user = await getUserById(userId);

  if (!user) {
    throw new Error('User not found');
  }

  // Get rating stats
  const ratingStatsQuery = `
    SELECT
      COUNT(*) as total_ratings,
      COALESCE(AVG(score), 0) as average_rating
    FROM ratings
    WHERE ratee_id = $1
  `;

  const ratingStats = await pool.query(ratingStatsQuery, [userId]);

  const stats: any = {
    total_ratings: parseInt(ratingStats.rows[0].total_ratings),
    average_rating: parseFloat(ratingStats.rows[0].average_rating),
  };

  // If driver, get trip stats
  if (user.role === UserRole.Driver) {
    const tripStatsQuery = `
      SELECT COUNT(*) as total_trips
      FROM trips
      WHERE driver_id = $1 AND status = 'completed'
    `;

    const tripStats = await pool.query(tripStatsQuery, [userId]);
    stats.total_trips_as_driver = parseInt(tripStats.rows[0].total_trips);
  }

  // Get booking stats (as rider)
  const bookingStatsQuery = `
    SELECT COUNT(*) as total_bookings
    FROM bookings
    WHERE rider_id = $1
      AND booking_state = 'completed'
  `;

  const bookingStats = await pool.query(bookingStatsQuery, [userId]);
  stats.total_bookings_as_rider = parseInt(bookingStats.rows[0].total_bookings);

  return stats;
};

/**
 * Save device push token for a user
 * @param userId User's UUID
 * @param deviceToken APNs/FCM device token
 */
export const saveDeviceToken = async (userId: string, deviceToken: string): Promise<void> => {
  await pool.query(
    `UPDATE users SET device_token = $1, updated_at = current_timestamp WHERE user_id = $2`,
    [deviceToken, userId]
  );
};

/**
 * Update notification preferences for a user
 * @param userId User's UUID
 * @param emailNotifications Enable email notifications
 * @param pushNotifications Enable push notifications
 */
export const updateNotificationPreferences = async (
  userId: string,
  emailNotifications: boolean,
  pushNotifications: boolean
): Promise<void> => {
  await pool.query(
    `UPDATE users SET email_notifications = $1, push_notifications = $2, updated_at = current_timestamp WHERE user_id = $3`,
    [emailNotifications, pushNotifications, userId]
  );
};

/**
 * Update user's profile picture URL
 * @param userId User's UUID
 * @param profilePictureUrl URL/path to profile picture, or null to clear
 * @returns Updated user profile
 */
export const updateProfilePicture = async (
  userId: string,
  profilePictureUrl: string | null
): Promise<SafeUser> => {
  const query = `
    UPDATE users
    SET profile_picture_url = $1, updated_at = current_timestamp
    WHERE user_id = $2
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, license_plate, earnings, mpg, profile_picture_url, created_at, updated_at
  `;

  const result = await pool.query(query, [profilePictureUrl, userId]);

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  return result.rows[0];
};

/**
 * Get driver earnings and statistics
 * @param userId User's UUID
 * @returns Driver earnings data
 */
export const getDriverEarnings = async (userId: string) => {
  const user = await getUserById(userId);

  if (!user || user.role !== UserRole.Driver) {
    throw new Error('User is not a driver');
  }

  const earningsQuery = `SELECT earnings FROM users WHERE user_id = $1`;
  const earningsResult = await pool.query(earningsQuery, [userId]);
  const totalEarned = parseFloat(earningsResult.rows[0].earnings || 0);

  const completedTripsQuery = `
    SELECT COUNT(*) as count FROM trips
    WHERE driver_id = $1 AND status = 'completed'
  `;
  const completedTrips = await pool.query(completedTripsQuery, [userId]);

  const activeTripsQuery = `
    SELECT COUNT(*) as count FROM trips
    WHERE driver_id = $1 AND status = 'pending'
  `;
  const activeTrips = await pool.query(activeTripsQuery, [userId]);

  const thisMonthQuery = `
    SELECT COALESCE(SUM(p.amount), 0) as month_total
    FROM payments p
    JOIN bookings b ON p.booking_id = b.booking_id
    JOIN trips t ON b.trip_id = t.trip_id
    WHERE t.driver_id = $1
      AND p.status = 'captured'
      AND DATE_TRUNC('month', p.updated_at) = DATE_TRUNC('month', CURRENT_DATE)
  `;
  const thisMonthResult = await pool.query(thisMonthQuery, [userId]);

  return {
    total_earned: totalEarned,
    trips_completed: parseInt(completedTrips.rows[0].count),
    trips_active: parseInt(activeTrips.rows[0].count),
    this_month_earned: parseFloat(thisMonthResult.rows[0].month_total || 0),
  };
};

/**
 * Create a report about another user
 * @param reportData Report details
 * @returns Created report
 */
export const createReport = async (reportData: {
  reporter_id: string;
  reported_user_id: string;
  trip_id?: string;
  category: string;
  description: string;
}): Promise<any> => {
  const query = `
    INSERT INTO reports (reporter_id, reported_user_id, trip_id, category, description, status)
    VALUES ($1, $2, $3, $4, $5, 'pending')
    RETURNING *
  `;

  const result = await pool.query(query, [
    reportData.reporter_id,
    reportData.reported_user_id,
    reportData.trip_id || null,
    reportData.category,
    reportData.description,
  ]);

  // Send email notification to admin
  // TODO: Add email service integration
  // await sendEmail({
  //   to: 'reports@lessgo.com', // Placeholder
  //   subject: `New Report: ${reportData.category}`,
  //   body: `Report from user ${reportData.reporter_id} about ${reportData.reported_user_id}`
  // });

  console.log(`📧 Report created: ${reportData.category} - Would send email to admin`);

  return result.rows[0];
};

/**
 * Get reports submitted by a user
 * @param userId User's UUID
 * @returns Array of reports
 */
export const getUserReports = async (userId: string): Promise<any[]> => {
  const query = `
    SELECT
      r.*,
      reporter.name as reporter_name,
      reported.name as reported_user_name
    FROM reports r
    JOIN users reporter ON r.reporter_id = reporter.user_id
    JOIN users reported ON r.reported_user_id = reported.user_id
    WHERE r.reporter_id = $1
    ORDER BY r.created_at DESC LIMIT 50
  `;

  const result = await pool.query(query, [userId]);
  return result.rows;
};

/**
 * Update user role (Driver ↔ Rider switching)
 * @param userId User's UUID
 * @param role New role ("Driver" or "Rider")
 * @returns Updated safe user object
 */
export const updateUserRole = async (userId: string, role: string): Promise<SafeUser> => {
  const query = `
    UPDATE users
    SET role = $1, updated_at = current_timestamp
    WHERE user_id = $2
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, license_plate, earnings, mpg, created_at, updated_at
  `;

  const result = await pool.query(query, [role, userId]);

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  console.log(`🔄 User ${userId} role updated to: ${role}`);

  return result.rows[0];
};

export default {
  getUserById,
  updateUserProfile,
  setupDriverProfile,
  getUserRatings,
  updateUserAverageRating,
  getUserStats,
  saveDeviceToken,
  updateNotificationPreferences,
  updateProfilePicture,
  getDriverEarnings,
  createReport,
  getUserReports,
  updateUserRole,
};
