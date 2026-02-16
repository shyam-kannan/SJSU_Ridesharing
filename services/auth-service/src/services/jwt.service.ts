import jwt from 'jsonwebtoken';
import { config } from '../config';
import { JWTPayload, UserRole, SJSUIdStatus } from '@lessgo/shared';

/**
 * Generate access token (short-lived)
 * @param userId User's UUID
 * @param email User's email
 * @param role User's role
 * @param sjsuIdStatus User's SJSU ID verification status
 * @returns JWT access token
 */
export const generateAccessToken = (
  userId: string,
  email: string,
  role: UserRole,
  sjsuIdStatus: SJSUIdStatus
): string => {
  const payload: JWTPayload = {
    userId,
    email,
    role,
    sjsuIdStatus,
    type: 'access',
  };

  const token = jwt.sign(payload, config.jwtSecret, {
    expiresIn: config.jwtAccessExpiry,
  } as jwt.SignOptions);

  return token;
};

/**
 * Generate refresh token (long-lived)
 * @param userId User's UUID
 * @returns JWT refresh token
 */
export const generateRefreshToken = (userId: string): string => {
  const payload: Partial<JWTPayload> = {
    userId,
    type: 'refresh',
  };

  const token = jwt.sign(payload, config.jwtSecret, {
    expiresIn: config.jwtRefreshExpiry,
  } as jwt.SignOptions);

  return token;
};

/**
 * Verify JWT token
 * @param token JWT token to verify
 * @returns Decoded token payload
 */
export const verifyToken = (token: string): JWTPayload => {
  try {
    const decoded = jwt.verify(token, config.jwtSecret) as JWTPayload;
    return decoded;
  } catch (error) {
    throw error;
  }
};

/**
 * Generate both access and refresh tokens
 * @param userId User's UUID
 * @param email User's email
 * @param role User's role
 * @param sjsuIdStatus User's SJSU ID verification status
 * @returns Object with access and refresh tokens
 */
export const generateTokenPair = (
  userId: string,
  email: string,
  role: UserRole,
  sjsuIdStatus: SJSUIdStatus
): { accessToken: string; refreshToken: string } => {
  const accessToken = generateAccessToken(userId, email, role, sjsuIdStatus);
  const refreshToken = generateRefreshToken(userId);

  return { accessToken, refreshToken };
};
