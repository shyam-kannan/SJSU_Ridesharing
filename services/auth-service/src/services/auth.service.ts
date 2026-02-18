import { Pool } from 'pg';
import { config } from '../config';
import { User, SafeUser, RegisterRequest, UserRole, SJSUIdStatus } from '@lessgo/shared';
import { hashPassword, comparePassword } from './bcrypt.service';

// Create database connection pool
const pool = new Pool({
  connectionString: config.databaseUrl,
});

/**
 * Create a new user account
 * @param userData User registration data
 * @param sjsuIdImagePath Optional path to uploaded SJSU ID image
 * @returns Created user (without password)
 */
export const createUser = async (
  userData: RegisterRequest,
  sjsuIdImagePath?: string
): Promise<SafeUser> => {
  const { name, email, password, role } = userData;

  // Hash password
  const passwordHash = await hashPassword(password);

  // Insert user into database
  const query = `
    INSERT INTO users (name, email, password_hash, role, sjsu_id_image_path, sjsu_id_status)
    VALUES ($1, $2, $3, $4, $5, $6)
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, created_at, updated_at
  `;

  const values = [
    name,
    email.toLowerCase(),
    passwordHash,
    role,
    sjsuIdImagePath || null,
    SJSUIdStatus.Pending, // Default status
  ];

  const result = await pool.query(query, values);
  const user = result.rows[0];

  return user;
};

/**
 * Find user by email
 * @param email User's email
 * @returns User if found, null otherwise
 */
export const findUserByEmail = async (email: string): Promise<User | null> => {
  const query = `
    SELECT * FROM users
    WHERE email = $1
  `;

  const result = await pool.query(query, [email.toLowerCase()]);

  if (result.rows.length === 0) {
    return null;
  }

  return result.rows[0];
};

/**
 * Find user by ID
 * @param userId User's UUID
 * @returns User if found, null otherwise
 */
export const findUserById = async (userId: string): Promise<User | null> => {
  const query = `
    SELECT * FROM users
    WHERE user_id = $1
  `;

  const result = await pool.query(query, [userId]);

  if (result.rows.length === 0) {
    return null;
  }

  return result.rows[0];
};

/**
 * Validate user credentials
 * @param email User's email
 * @param password Plain text password
 * @returns User if credentials are valid, null otherwise
 */
export const validateCredentials = async (
  email: string,
  password: string
): Promise<SafeUser | null> => {
  const user = await findUserByEmail(email);

  if (!user) {
    return null;
  }

  const isPasswordValid = await comparePassword(password, user.password_hash);

  if (!isPasswordValid) {
    return null;
  }

  // Return user without password
  const { password_hash, ...safeUser } = user;
  return safeUser as SafeUser;
};

/**
 * Remove password from user object
 * @param user User object with password
 * @returns User object without password
 */
export const toSafeUser = (user: User): SafeUser => {
  const { password_hash, ...safeUser } = user;
  return safeUser as SafeUser;
};

/**
 * Save SJSU ID image path and set status to pending
 * @param userId User's UUID
 * @param imagePath Path to the uploaded image
 * @returns Updated user (safe)
 */
export const submitSJSUIdImage = async (
  userId: string,
  imagePath: string
): Promise<SafeUser> => {
  const query = `
    UPDATE users
    SET sjsu_id_image_path = $1, sjsu_id_status = $2, updated_at = current_timestamp
    WHERE user_id = $3
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, created_at, updated_at
  `;

  const result = await pool.query(query, [imagePath, SJSUIdStatus.Pending, userId]);

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  return result.rows[0];
};

/**
 * Update user's SJSU ID verification status (admin only)
 * @param userId User's UUID
 * @param status New SJSU ID status
 * @returns Updated user
 */
export const updateSJSUIdStatus = async (
  userId: string,
  status: SJSUIdStatus
): Promise<SafeUser> => {
  const query = `
    UPDATE users
    SET sjsu_id_status = $1, updated_at = current_timestamp
    WHERE user_id = $2
    RETURNING user_id, name, email, role, sjsu_id_status, rating, vehicle_info, seats_available, created_at, updated_at
  `;

  const result = await pool.query(query, [status, userId]);

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  return result.rows[0];
};

/**
 * Change user's password
 * @param userId User's UUID
 * @param currentPassword Current plain-text password
 * @param newPassword New plain-text password
 */
export const changePassword = async (
  userId: string,
  currentPassword: string,
  newPassword: string
): Promise<void> => {
  // Fetch user with password hash
  const query = `SELECT * FROM users WHERE user_id = $1`;
  const result = await pool.query(query, [userId]);

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  const user: User = result.rows[0];

  // Verify current password
  const isValid = await comparePassword(currentPassword, user.password_hash);
  if (!isValid) {
    throw new Error('Current password is incorrect');
  }

  // Hash new password and update
  const newHash = await hashPassword(newPassword);
  await pool.query(
    `UPDATE users SET password_hash = $1, updated_at = current_timestamp WHERE user_id = $2`,
    [newHash, userId]
  );
};

export default {
  createUser,
  findUserByEmail,
  findUserById,
  validateCredentials,
  toSafeUser,
  submitSJSUIdImage,
  updateSJSUIdStatus,
  changePassword,
};
