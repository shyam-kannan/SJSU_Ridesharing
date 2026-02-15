import { Pool } from 'pg';
import { config } from '../config';
import { SafeUser, Rating, RatingWithUsers, DriverSetupRequest, UserRole } from '../../../shared/types';

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
    SELECT user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, created_at, updated_at
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
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, created_at, updated_at
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
  const { vehicle_info, seats_available } = driverData;

  const query = `
    UPDATE users
    SET
      role = $1,
      vehicle_info = $2,
      seats_available = $3,
      updated_at = current_timestamp
    WHERE user_id = $4
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, created_at, updated_at
  `;

  const result = await pool.query(query, [
    UserRole.Driver,
    vehicle_info,
    seats_available,
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
      WHERE driver_id = $1
    `;

    const tripStats = await pool.query(tripStatsQuery, [userId]);
    stats.total_trips_as_driver = parseInt(tripStats.rows[0].total_trips);
  }

  // Get booking stats (as rider)
  const bookingStatsQuery = `
    SELECT COUNT(*) as total_bookings
    FROM bookings
    WHERE rider_id = $1
  `;

  const bookingStats = await pool.query(bookingStatsQuery, [userId]);
  stats.total_bookings_as_rider = parseInt(bookingStats.rows[0].total_bookings);

  return stats;
};

export default {
  getUserById,
  updateUserProfile,
  setupDriverProfile,
  getUserRatings,
  updateUserAverageRating,
  getUserStats,
};
