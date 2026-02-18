import express from 'express';
import * as userController from '../controllers/user.controller';
import { authenticateToken, asyncHandler } from '@lessgo/shared';
import { body } from 'express-validator';

const router = express.Router();

/**
 * @route   GET /users/me
 * @desc    Get current user's profile
 * @access  Private
 */
router.get('/me', authenticateToken, asyncHandler(userController.getCurrentUserProfile));

/**
 * @route   GET /users/:id
 * @desc    Get user profile by ID
 * @access  Public
 */
router.get('/:id', asyncHandler(userController.getUserProfile));

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

export default router;
