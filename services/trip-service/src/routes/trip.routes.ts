import express from 'express';
import * as tripController from '../controllers/trip.controller';
import { authenticateToken, requireDriver, requireVerifiedStudent, asyncHandler } from '@lessgo/shared';
import { body, validationResult } from 'express-validator';

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
  validateRequest,
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
 * @route   GET /trips/:id/bookings
 * @desc    Get all bookings for a trip (passengers list)
 * @access  Private (Driver only - must own the trip)
 */
router.get('/:id/bookings', authenticateToken, asyncHandler(tripController.getTripBookings));

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
  validateRequest,
  asyncHandler(tripController.updateTrip)
);

/**
 * @route   PUT /trips/:id/state
 * @desc    Update trip state (for real-time ride tracking)
 * @access  Private (Driver only - must own the trip)
 */
router.put(
  '/:id/state',
  authenticateToken,
  [body('status').notEmpty().withMessage('Status is required').trim()],
  validateRequest,
  asyncHandler(tripController.updateTripState)
);

/**
 * @route   DELETE /trips/:id
 * @desc    Cancel trip
 * @access  Private (Own trip only)
 */
router.delete('/:id', authenticateToken, asyncHandler(tripController.cancelTrip));



/**
 * @route   POST /trips/:id/location
 * @desc    Update driver location for active trip
 * @access  Private (Driver only - must own the trip)
 */
router.post(
  '/:id/location',
  authenticateToken,
  [
    body('latitude').notEmpty().withMessage('Latitude is required').isFloat(),
    body('longitude').notEmpty().withMessage('Longitude is required').isFloat(),
    body('heading').optional().isFloat(),
    body('speed').optional().isFloat(),
    body('accuracy').optional().isFloat(),
  ],
  validateRequest,
  asyncHandler(tripController.updateTripLocation)
);

/**
 * @route   GET /trips/:id/location
 * @desc    Get latest driver location for trip
 * @access  Public (riders need to see driver location)
 */
router.get('/:id/location', asyncHandler(tripController.getTripLocation));

/**
 * @route   POST /trips/:id/messages
 * @desc    Send a message in trip chat
 * @access  Private (Driver or Rider with booking)
 */
router.post(
  '/:id/messages',
  authenticateToken,
  [body('message').notEmpty().withMessage('Message is required').trim()],
  validateRequest,
  asyncHandler(tripController.sendMessage)
);

/**
 * @route   GET /trips/:id/messages
 * @desc    Get messages for a trip
 * @access  Private (Driver or Rider with booking)
 */
router.get('/:id/messages', authenticateToken, asyncHandler(tripController.getTripMessages));

export default router;
