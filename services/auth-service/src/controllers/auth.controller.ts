import { Request, Response } from 'express';
import * as authService from '../services/auth.service';
import * as jwtService from '../services/jwt.service';
import { RegisterRequest, LoginRequest, AuthResponse, AppError, successResponse, errorResponse, SJSUIdStatus } from '@lessgo/shared';

/**
 * Register a new user
 * POST /auth/register
 */
export const register = async (req: Request, res: Response): Promise<void> => {
  try {
    const userData: RegisterRequest = req.body;
    const sjsuIdImage = req.file; // Multer file upload

    // Check if user already exists
    const existingUser = await authService.findUserByEmail(userData.email);
    if (existingUser) {
      errorResponse(res, 'User with this email already exists', 409);
      return;
    }

    // Create user
    const sjsuIdImagePath = sjsuIdImage ? sjsuIdImage.path : undefined;
    const user = await authService.createUser(userData, sjsuIdImagePath);

    // Generate tokens
    const { accessToken, refreshToken } = jwtService.generateTokenPair(
      user.user_id,
      user.email,
      user.role,
      user.sjsu_id_status
    );

    const response: AuthResponse = {
      user,
      accessToken,
      refreshToken,
    };

    successResponse(res, response, 'User registered successfully', 201);
  } catch (error) {
    console.error('Registration error:', error);
    if (error instanceof AppError) {
      throw error;
    }
    throw new AppError('Registration failed', 500);
  }
};

/**
 * Login user
 * POST /auth/login
 */
export const login = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password }: LoginRequest = req.body;

    // Validate credentials
    const user = await authService.validateCredentials(email, password);

    if (!user) {
      errorResponse(res, 'Invalid email or password', 401);
      return;
    }

    // Generate tokens
    const { accessToken, refreshToken } = jwtService.generateTokenPair(
      user.user_id,
      user.email,
      user.role,
      user.sjsu_id_status
    );

    const response: AuthResponse = {
      user,
      accessToken,
      refreshToken,
    };

    successResponse(res, response, 'Login successful');
  } catch (error) {
    console.error('Login error:', error);
    if (error instanceof AppError) {
      throw error;
    }
    throw new AppError('Login failed', 500);
  }
};

/**
 * Refresh access token
 * POST /auth/refresh
 */
export const refreshToken = async (req: Request, res: Response): Promise<void> => {
  try {
    const { refreshToken } = req.body;

    // Verify refresh token
    const decoded = jwtService.verifyToken(refreshToken);

    if (decoded.type !== 'refresh') {
      errorResponse(res, 'Invalid token type', 403);
      return;
    }

    // Get user from database
    const user = await authService.findUserById(decoded.userId);

    if (!user) {
      errorResponse(res, 'User not found', 404);
      return;
    }

    // Generate new access token
    const newAccessToken = jwtService.generateAccessToken(
      user.user_id,
      user.email,
      user.role,
      user.sjsu_id_status
    );

    successResponse(
      res,
      { accessToken: newAccessToken },
      'Access token refreshed successfully'
    );
  } catch (error) {
    console.error('Refresh token error:', error);
    if (error instanceof Error && error.name === 'TokenExpiredError') {
      errorResponse(res, 'Refresh token expired. Please login again', 401);
      return;
    }
    if (error instanceof Error && error.name === 'JsonWebTokenError') {
      errorResponse(res, 'Invalid refresh token', 403);
      return;
    }
    throw new AppError('Token refresh failed', 500);
  }
};

/**
 * Verify token validity
 * GET /auth/verify
 */
export const verifyTokenEndpoint = async (req: Request, res: Response): Promise<void> => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      errorResponse(res, 'Token required', 401);
      return;
    }

    // Verify token
    const decoded = jwtService.verifyToken(token);

    // Get user from database
    const user = await authService.findUserById(decoded.userId);

    if (!user) {
      errorResponse(res, 'User not found', 404);
      return;
    }

    const safeUser = authService.toSafeUser(user);

    successResponse(res, { valid: true, user: safeUser }, 'Token is valid');
  } catch (error) {
    if (error instanceof Error && error.name === 'TokenExpiredError') {
      errorResponse(res, 'Token expired', 401);
      return;
    }
    if (error instanceof Error && error.name === 'JsonWebTokenError') {
      errorResponse(res, 'Invalid token', 403);
      return;
    }
    throw new AppError('Token verification failed', 500);
  }
};

/**
 * Logout user (client-side token deletion)
 * POST /auth/logout
 */
export const logout = async (req: Request, res: Response): Promise<void> => {
  // In a stateless JWT system, logout is typically handled client-side
  // by deleting the tokens. This endpoint is mainly for completeness.
  // For a more robust solution, implement token blacklisting with Redis.

  successResponse(
    res,
    null,
    'Logout successful. Please delete your tokens on the client side.'
  );
};

/**
 * Get current user (from token)
 * GET /auth/me
 */
export const getCurrentUser = async (req: Request, res: Response): Promise<void> => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      errorResponse(res, 'Token required', 401);
      return;
    }

    const decoded = jwtService.verifyToken(token);
    const user = await authService.findUserById(decoded.userId);

    if (!user) {
      errorResponse(res, 'User not found', 404);
      return;
    }

    const safeUser = authService.toSafeUser(user);
    successResponse(res, safeUser, 'User retrieved successfully');
  } catch (error) {
    if (error instanceof Error && error.name === 'TokenExpiredError') {
      errorResponse(res, 'Token expired', 401);
      return;
    }
    if (error instanceof Error && error.name === 'JsonWebTokenError') {
      errorResponse(res, 'Invalid token', 403);
      return;
    }
    throw new AppError('Failed to get current user', 500);
  }
};

/**
 * Submit SJSU ID image for verification
 * POST /auth/verify-id
 * Accepts multipart/form-data with field "sjsuId"
 */
export const submitSJSUId = async (req: Request, res: Response): Promise<void> => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      errorResponse(res, 'Token required', 401);
      return;
    }

    const decoded = jwtService.verifyToken(token);
    const userId = decoded.userId;

    if (!req.file) {
      errorResponse(res, 'SJSU ID image is required', 400);
      return;
    }

    const updatedUser = await authService.submitSJSUIdImage(userId, req.file.path);
    successResponse(res, updatedUser, 'SJSU ID submitted for verification');
  } catch (error) {
    console.error('Verify ID error:', error);
    if (error instanceof Error && error.name === 'TokenExpiredError') {
      errorResponse(res, 'Token expired', 401);
      return;
    }
    if (error instanceof Error && error.name === 'JsonWebTokenError') {
      errorResponse(res, 'Invalid token', 403);
      return;
    }
    throw new AppError('Failed to submit SJSU ID', 500);
  }
};

/**
 * Change user's password
 * PUT /auth/change-password
 */
export const changePassword = async (req: Request, res: Response): Promise<void> => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) { errorResponse(res, 'Token required', 401); return; }

    const decoded = jwtService.verifyToken(token);
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      errorResponse(res, 'currentPassword and newPassword are required', 400);
      return;
    }
    if (newPassword.length < 8) {
      errorResponse(res, 'New password must be at least 8 characters', 400);
      return;
    }

    await authService.changePassword(decoded.userId, currentPassword, newPassword);
    successResponse(res, null, 'Password changed successfully');
  } catch (error) {
    if (error instanceof Error && error.message === 'Current password is incorrect') {
      errorResponse(res, 'Current password is incorrect', 400);
      return;
    }
    if (error instanceof Error && error.name === 'TokenExpiredError') {
      errorResponse(res, 'Token expired', 401);
      return;
    }
    throw new AppError('Failed to change password', 500);
  }
};

/**
 * Test-only: Verify a user's SJSU ID status
 * POST /auth/test/verify/:userId
 * Only available in development mode
 */
export const testVerifyUser = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;

  const user = await authService.findUserById(userId);
  if (!user) {
    errorResponse(res, 'User not found', 404);
    return;
  }

  const updatedUser = await authService.updateSJSUIdStatus(userId, SJSUIdStatus.Verified);
  successResponse(res, updatedUser, 'User SJSU ID verified (test only)');
};
