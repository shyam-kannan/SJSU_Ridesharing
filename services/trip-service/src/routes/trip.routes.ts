import express from 'express';
import * as tripController from '../controllers/trip.controller';
import { authenticateToken, requireDriver, requireVerifiedStudent } from '../../../shared/middleware/auth';
import { asyncHandler } from '../../../shared/middleware/errorHandler';
import { body } from 'express-validator';

const router = express.Router();

/**
 * @route   POST /trips
 * @desc    Create a new trip
 * @access  Private (Driver only, Verified SJSU ID)
 */
router.post(
  '/',
  authenticateToken,
  requireDriver,
  requireVerifiedStudent,
  [
    body('origin').notEmpty().withMessage('Origin is required').trim(),
    body('destination').notEmpty().withMessage('Destination is required').trim(),
    body('departure_time').notEmpty().withMessage('Departure time is required').isISO8601(),
    body('seats_available')
      .notEmpty()
      .withMessage('Seats available is required')
      .isInt({ min: 1, max: 8 })
      .withMessage('Seats available must be between 1 and 8'),
    body('recurrence').optional().trim(),
  ],
  asyncHandler(tripController.createTrip)
);

/**
 * @route   GET /trips/search
 * @desc    Search for trips near a location
 * @access  Public (but typically requires authentication for booking)
 */
router.get('/search', asyncHandler(tripController.searchTrips));

/**
 * @route   GET /trips
 * @desc    List trips with filters
 * @access  Public
 */
router.get('/', asyncHandler(tripController.listTrips));

/**
 * @route   GET /trips/:id
 * @desc    Get trip by ID
 * @access  Public
 */
router.get('/:id', asyncHandler(tripController.getTrip));

/**
 * @route   PUT /trips/:id
 * @desc    Update trip
 * @access  Private (Own trip only)
 */
router.put(
  '/:id',
  authenticateToken,
  [
    body('departure_time').optional().isISO8601(),
    body('seats_available').optional().isInt({ min: 1, max: 8 }),
    body('recurrence').optional().trim(),
  ],
  asyncHandler(tripController.updateTrip)
);

/**
 * @route   DELETE /trips/:id
 * @desc    Cancel trip
 * @access  Private (Own trip only)
 */
router.delete('/:id', authenticateToken, asyncHandler(tripController.cancelTrip));

export default router;
