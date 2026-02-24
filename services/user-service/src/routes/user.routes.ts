import express from 'express';
import * as userController from '../controllers/user.controller';
import { authenticateToken, asyncHandler } from '@lessgo/shared';
import { body, validationResult } from 'express-validator';
import { profilePictureUpload } from '../middleware/upload';

const router = express.Router();

const validateRequest = (req: express.Request, res: express.Response, next: express.NextFunction) => {
  const errors = validationResult(req);
  if (errors.isEmpty()) {
    return next();
  }

  return res.status(400).json({
    status: 'error',
    message: 'Validation failed',
    errors: errors.array().map((e) => ({
      field: 'path' in e ? e.path : undefined,
      message: e.msg,
    })),
  });
};

/**
 * @route   GET /users/me
 * @desc    Get current user's profile
 * @access  Private
 */
router.get('/me', authenticateToken, asyncHandler(userController.getCurrentUserProfile));

/**
 * @route   PUT /users/:id
 * @desc    Update user profile
 * @access  Private (own profile only)
 */
router.put(
  '/:id',
  authenticateToken,
  [
    body('name').optional().trim().isLength({ min: 2, max: 255 }),
    body('email').optional().trim().isEmail().normalizeEmail(),
  ],
  validateRequest,
  asyncHandler(userController.updateProfile)
);

/**
 * @route   PUT /users/:id/driver-setup
 * @desc    Setup driver profile
 * @access  Private (own profile only)
 */
router.put(
  '/:id/driver-setup',
  authenticateToken,
  [
    body('vehicle_info')
      .notEmpty()
      .withMessage('Vehicle info is required')
      .trim()
      .isLength({ min: 5, max: 500 }),
    body('seats_available')
      .notEmpty()
      .withMessage('Seats available is required')
      .isInt({ min: 1, max: 8 })
      .withMessage('Seats available must be between 1 and 8'),
  ],
  validateRequest,
  asyncHandler(userController.setupDriver)
);

/**
 * @route   GET /users/:id/ratings
 * @desc    Get user's ratings
 * @access  Public
 */
router.get('/:id/ratings', asyncHandler(userController.getUserRatings));

/**
 * @route   GET /users/:id/stats
 * @desc    Get user statistics
 * @access  Public
 */
router.get('/:id/stats', asyncHandler(userController.getUserStatistics));

/**
 * @route   GET /users/:id/earnings
 * @desc    Get driver earnings and statistics
 * @access  Private (own driver only)
 */
router.get('/:id/earnings', authenticateToken, asyncHandler(userController.getDriverEarnings));

/**
 * @route   POST /users/:userId/device-token
 * @desc    Register device push token
 * @access  Private (own user only)
 */
router.post('/:userId/device-token', authenticateToken, asyncHandler(userController.registerDeviceToken));

/**
 * @route   PUT /users/:userId/preferences
 * @desc    Update notification preferences
 * @access  Private (own user only)
 */
router.put('/:userId/preferences', authenticateToken, asyncHandler(userController.updatePreferences));

/**
 * @route   POST /users/:userId/profile-picture
 * @desc    Upload profile picture
 * @access  Private (own user only)
 */
router.post(
  '/:userId/profile-picture',
  authenticateToken,
  profilePictureUpload.single('image'),
  asyncHandler(userController.uploadProfilePicture)
);

/**
 * @route   DELETE /users/:userId/profile-picture
 * @desc    Delete profile picture
 * @access  Private (own user only)
 */
router.delete('/:userId/profile-picture', authenticateToken, asyncHandler(userController.deleteProfilePicture));

/**
 * @route   POST /reports
 * @desc    Create a report about another user
 * @access  Private
 */
router.post('/reports', authenticateToken, asyncHandler(userController.createReport));

/**
 * @route   GET /reports
 * @desc    Get user's submitted reports
 * @access  Private
 */
router.get('/reports', authenticateToken, asyncHandler(userController.getReports));

/**
 * @route   GET /users/:id
 * @desc    Get user profile by ID
 * @access  Public
 */
router.get('/:id', asyncHandler(userController.getUserProfile));

/**
 * @route   PUT /users/:userId/role
 * @desc    Update user role (Driver ↔ Rider switching)
 * @access  Private (own user only)
 */
router.put('/:userId/role', authenticateToken, asyncHandler(userController.updateUserRole));

export default router;
