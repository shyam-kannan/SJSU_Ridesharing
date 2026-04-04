import { Response } from 'express';
import * as userService from '../services/user.service';
import { AuthRequest, AppError, successResponse, errorResponse, DriverSetupRequest } from '@lessgo/shared';
import path from 'path';
import fs from 'fs';

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
    if (!driverData.vehicle_info || !driverData.seats_available || !driverData.license_plate) {
      errorResponse(res, 'Vehicle info, seats available, and license plate are required', 400);
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

/**
 * Upload profile picture
 * POST /users/:userId/profile-picture
 */
export const uploadProfilePicture = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;

    // Check if user is uploading their own picture
    if (!req.user || req.user.userId !== userId) {
      errorResponse(res, 'You can only upload your own profile picture', 403);
      return;
    }

    if (!req.file) {
      errorResponse(res, 'No file uploaded', 400);
      return;
    }

    // Get file extension and construct URL path
    const ext = path.extname(req.file.filename);
    const profilePictureUrl = `/uploads/profile-pictures/${userId}${ext}`;

    // Update user's profile_picture_url in database
    const updatedUser = await userService.updateProfilePicture(userId, profilePictureUrl);

    successResponse(res, updatedUser, 'Profile picture uploaded successfully');
  } catch (error) {
    console.error('Upload profile picture error:', error);
    // Clean up uploaded file on error
    if (req.file) {
      try {
        fs.unlinkSync(req.file.path);
      } catch (unlinkError) {
        console.error('Failed to delete file:', unlinkError);
      }
    }
    throw new AppError('Failed to upload profile picture', 500);
  }
};

/**
 * Delete profile picture
 * DELETE /users/:userId/profile-picture
 */
export const deleteProfilePicture = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;

    // Check if user is deleting their own picture
    if (!req.user || req.user.userId !== userId) {
      errorResponse(res, 'You can only delete your own profile picture', 403);
      return;
    }

    // Get current user to find existing profile picture
    const user = await userService.getUserById(userId);

    if (!user) {
      errorResponse(res, 'User not found', 404);
      return;
    }

    // Delete old profile picture file if exists
    if (user.profile_picture_url) {
      const uploadsDir = path.join(__dirname, '../../uploads/profile-pictures');
      const possibleExtensions = ['.jpg', '.jpeg', '.png'];

      for (const ext of possibleExtensions) {
        const filePath = path.join(uploadsDir, `${userId}${ext}`);
        if (fs.existsSync(filePath)) {
          try {
            fs.unlinkSync(filePath);
            console.log(`Deleted profile picture: ${filePath}`);
          } catch (err) {
            console.error('Failed to delete file:', err);
          }
        }
      }
    }

    // Clear profile_picture_url in database
    const updatedUser = await userService.updateProfilePicture(userId, null);

    successResponse(res, updatedUser, 'Profile picture deleted successfully');
  } catch (error) {
    console.error('Delete profile picture error:', error);
    throw new AppError('Failed to delete profile picture', 500);
  }
};

/**
 * Get driver earnings and statistics
 * GET /users/:id/earnings
 */
export const getDriverEarnings = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    if (!req.user || req.user.userId !== id) {
      errorResponse(res, 'You can only view your own earnings', 403);
      return;
    }

    const earnings = await userService.getDriverEarnings(id);
    successResponse(res, earnings, 'Driver earnings retrieved successfully');
  } catch (error) {
    console.error('Get driver earnings error:', error);
    if (error instanceof Error && error.message === 'User is not a driver') {
      errorResponse(res, 'User is not a driver', 403);
      return;
    }
    throw new AppError('Failed to get driver earnings', 500);
  }
};

/**
 * Create a report about another user
 * POST /reports
 */
export const createReport = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const { reported_user_id, trip_id, category, description } = req.body;

    if (!reported_user_id || !category || !description) {
      errorResponse(res, 'reported_user_id, category, and description are required', 400);
      return;
    }

    const validCategories = [
      'safety_concern',
      'inappropriate_behavior',
      'cleanliness',
      'harassment',
      'discrimination',
      'route_issue',
      'payment_dispute',
      'no_show',
      'other',
    ];

    if (!validCategories.includes(category)) {
      errorResponse(res, 'Invalid category', 400);
      return;
    }

    const report = await userService.createReport({
      reporter_id: req.user.userId,
      reported_user_id,
      trip_id,
      category,
      description,
    });

    successResponse(res, report, 'Report created successfully', 201);
  } catch (error) {
    console.error('Create report error:', error);
    throw new AppError('Failed to create report', 500);
  }
};

/**
 * Get user's submitted reports
 * GET /reports
 */
export const getReports = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const reports = await userService.getUserReports(req.user.userId);
    successResponse(res, { reports, total: reports.length }, 'Reports retrieved successfully');
  } catch (error) {
    console.error('Get reports error:', error);
    throw new AppError('Failed to get reports', 500);
  }
};

/**
 * Update user role (Driver ↔ Rider switching)
 * PUT /users/:userId/role
 */
export const updateUserRole = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { userId } = req.params;
    const { role } = req.body;

    // Validate authentication and authorization
    if (!req.user || req.user.userId !== userId) {
      errorResponse(res, 'You can only update your own role', 403);
      return;
    }

    // Validate role value
    if (!role || !['Driver', 'Rider'].includes(role)) {
      errorResponse(res, 'Role must be either "Driver" or "Rider"', 400);
      return;
    }

    // If switching to Driver, validate vehicle info exists
    if (role === 'Driver') {
      const currentUser = await userService.getUserById(userId);
      if (!currentUser || !currentUser.vehicle_info || !currentUser.license_plate) {
        errorResponse(res, 'Complete driver setup (vehicle info and license plate) before switching to driver mode', 400);
        return;
      }
    }

    const updatedUser = await userService.updateUserRole(userId, role);
    successResponse(res, updatedUser, 'Role updated successfully');
  } catch (error) {
    console.error('Update user role error:', error);
    throw new AppError('Failed to update role', 500);
  }
};
