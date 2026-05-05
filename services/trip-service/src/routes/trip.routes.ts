import express from 'express';
import * as tripController from '../controllers/trip.controller';
import * as matchingController from '../controllers/matching.controller';
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

// ─── Debug / simulation routes (before /:id to avoid param shadowing) ────────

/**
 * @route   POST /trips/debug-seed-history
 * @desc    Dev-only: insert completed historical trips + run frequent-route mining
 * @access  Dev-only (returns 403 in production)
 */
router.post('/debug-seed-history', asyncHandler(matchingController.seedTripHistory));

/**
 * @route   GET /trips/driver/:driverId/frequent-routes
 * @desc    Return GPS-centered frequent-route segments mined from completed trip history
 * @access  Public (driver ID in path)
 */
router.get('/driver/:driverId/frequent-routes', asyncHandler(matchingController.getDriverFrequentRoutes));

// ─── On-demand matching routes (must be before /:id to avoid shadowing) ──────

/**
 * @route   POST /trips/request
 * @desc    Rider submits a ride request; triggers matching pipeline
 * @access  Private
 */
router.post(
  '/request',
  authenticateToken,
  [
    body('origin').notEmpty().trim(),
    body('destination').notEmpty().trim(),
    body('origin_lat').isFloat(),
    body('origin_lng').isFloat(),
    body('destination_lat').isFloat(),
    body('destination_lng').isFloat(),
    body('departure_time').isISO8601(),
  ],
  validateRequest,
  asyncHandler(matchingController.requestTrip)
);

/**
 * @route   GET /trips/request/:id
 * @desc    Poll status of a ride request
 * @access  Private
 */
router.get('/request/:id', authenticateToken, asyncHandler(matchingController.getTripRequest));

/**
 * @route   POST /trips/request/:id/select-driver
 * @desc    Rider selects a driver from the ranked list; sends the driver an accept/deny notification
 * @access  Private
 */
router.post(
  '/request/:id/select-driver',
  authenticateToken,
  [
    body('trip_id').notEmpty().withMessage('trip_id required'),
    body('driver_id').notEmpty().withMessage('driver_id required'),
  ],
  validateRequest,
  asyncHandler(matchingController.selectDriver)
);

// ─────────────────────────────────────────────────────────────────────────────

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

/**
 * @route   POST /trips/:id/accept-match
 * @desc    Driver accepts an incoming match
 * @access  Private
 */
router.post(
  '/:id/accept-match',
  authenticateToken,
  [body('match_id').notEmpty()],
  validateRequest,
  asyncHandler(matchingController.acceptRideMatch)
);

/**
 * @route   POST /trips/:id/decline-match
 * @desc    Driver declines an incoming match (retry fires automatically)
 * @access  Private
 */
router.post(
  '/:id/decline-match',
  authenticateToken,
  [body('match_id').notEmpty()],
  validateRequest,
  asyncHandler(matchingController.declineRideMatch)
);

/**
 * @route   POST /trips/:id/merge-route
 * @desc    Manually trigger route re-merge for a new rider
 * @access  Private (Driver only)
 */
router.post(
  '/:id/merge-route',
  authenticateToken,
  [
    body('rider_id').notEmpty(),
    body('pickup_lat').isFloat(),
    body('pickup_lng').isFloat(),
    body('dropoff_lat').isFloat(),
    body('dropoff_lng').isFloat(),
  ],
  validateRequest,
  asyncHandler(matchingController.triggerMergeRoute)
);

/**
 * @route   GET /trips/:id/anchor-points
 * @desc    Return anchor points for iOS multi-segment route rendering
 * @access  Public
 */
router.get('/:id/anchor-points', asyncHandler(matchingController.fetchAnchorPoints));

export default router;
