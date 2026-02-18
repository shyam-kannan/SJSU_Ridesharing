import { Response } from 'express';
import * as userService from '../services/user.service';
import { AuthRequest, AppError, successResponse, errorResponse, DriverSetupRequest } from '@lessgo/shared';

/**
 * Get user profile by ID
 * GET /users/:id
 */
export const getUserProfile = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const user = await userService.getUserById(id);

    if (!user) {
      errorResponse(res, 'User not found', 404);
      return;
    }

    successResponse(res, user, 'User profile retrieved successfully');
  } catch (error) {
    console.error('Get user profile error:', error);
    throw new AppError('Failed to get user profile', 500);
  }
};

/**
 * Get current user's profile (from token)
 * GET /users/me
 */
export const getCurrentUserProfile = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const user = await userService.getUserById(req.user.userId);

    if (!user) {
      errorResponse(res, 'User not found', 404);
      return;
    }

    successResponse(res, user, 'User profile retrieved successfully');
  } catch (error) {
    console.error('Get current user profile error:', error);
    throw new AppError('Failed to get user profile', 500);
  }
};

/**
 * Update user profile
 * PUT /users/:id
 */
export const updateProfile = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updates = req.body;

    // Check if user is updating their own profile
    if (!req.user || req.user.userId !== id) {
      errorResponse(res, 'You can only update your own profile', 403);
      return;
    }

    const updatedUser = await userService.updateUserProfile(id, updates);

    successResponse(res, updatedUser, 'Profile updated successfully');
  } catch (error) {
    console.error('Update profile error:', error);
    if (error instanceof Error && error.message === 'No fields to update') {
      errorResponse(res, 'No fields to update', 400);
      return;
    }
    if (error instanceof Error && error.message === 'User not found') {
      errorResponse(res, 'User not found', 404);
      return;
    }
    throw new AppError('Failed to update profile', 500);
  }
};

/**
 * Setup driver profile
 * PUT /users/:id/driver-setup
 */
export const setupDriver = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const driverData: DriverSetupRequest = req.body;

    // Check if user is updating their own profile
    if (!req.user || req.user.userId !== id) {
      errorResponse(res, 'You can only setup your own driver profile', 403);
      return;
    }

    // Validate driver data
    if (!driverData.vehicle_info || !driverData.seats_available) {
      errorResponse(res, 'Vehicle info and seats available are required', 400);
      return;
    }

    if (driverData.seats_available < 1 || driverData.seats_available > 8) {
      errorResponse(res, 'Seats available must be between 1 and 8', 400);
      return;
    }

    const updatedUser = await userService.setupDriverProfile(id, driverData);

    successResponse(res, updatedUser, 'Driver profile setup successfully');
  } catch (error) {
    console.error('Setup driver profile error:', error);
    if (error instanceof Error && error.message === 'User not found') {
      errorResponse(res, 'User not found', 404);
      return;
    }
    throw new AppError('Failed to setup driver profile', 500);
  }
};

/**
 * Get user's ratings
 * GET /users/:id/ratings
 */
export const getUserRatings = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const ratings = await userService.getUserRatings(id);

    const averageRating = ratings.length > 0
      ? ratings.reduce((sum, r) => sum + r.score, 0) / ratings.length
      : 0;

    successResponse(
      res,
      {
        ratings,
        total_ratings: ratings.length,
        average_rating: parseFloat(averageRating.toFixed(2)),
      },
      'User ratings retrieved successfully'
    );
  } catch (error) {
    console.error('Get user ratings error:', error);
    throw new AppError('Failed to get user ratings', 500);
  }
};

/**
 * Register device push token
 * POST /users/:userId/device-token
 */
export const registerDeviceToken = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { deviceToken } = req.body;

    if (!req.user || req.user.userId !== userId) {
      errorResponse(res, 'Unauthorized', 403);
      return;
    }

    if (!deviceToken) {
      errorResponse(res, 'deviceToken is required', 400);
      return;
    }

    await userService.saveDeviceToken(userId, deviceToken);
    successResponse(res, null, 'Device token registered');
  } catch (error) {
    console.error('Register device token error:', error);
    throw new AppError('Failed to register device token', 500);
  }
};

/**
 * Update notification preferences
 * PUT /users/:userId/preferences
 */
export const updatePreferences = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { emailNotifications, pushNotifications } = req.body;

    if (!req.user || req.user.userId !== userId) {
      errorResponse(res, 'Unauthorized', 403);
      return;
    }

    await userService.updateNotificationPreferences(
      userId,
      emailNotifications !== false,
      pushNotifications !== false
    );
    successResponse(res, null, 'Preferences updated');
  } catch (error) {
    console.error('Update preferences error:', error);
    throw new AppError('Failed to update preferences', 500);
  }
};

/**
 * Get user statistics
 * GET /users/:id/stats
 */
export const getUserStatistics = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const stats = await userService.getUserStats(id);

    successResponse(res, stats, 'User statistics retrieved successfully');
  } catch (error) {
    console.error('Get user statistics error:', error);
    if (error instanceof Error && error.message === 'User not found') {
      errorResponse(res, 'User not found', 404);
      return;
    }
    throw new AppError('Failed to get user statistics', 500);
  }
};
