import express from 'express';
import * as bookingController from '../controllers/booking.controller';
import { authenticateToken, requireVerifiedStudent, asyncHandler } from '@lessgo/shared';
import { body } from 'express-validator';

const router = express.Router();

router.post(
  '/',
  authenticateToken,
  requireVerifiedStudent,
  [
    body('trip_id').notEmpty().withMessage('Trip ID is required').isUUID(),
    body('seats_booked').isInt({ min: 1, max: 8 }).withMessage('Seats booked must be 1-8'),
  ],
  asyncHandler(bookingController.createBooking)
);

router.get('/', authenticateToken, asyncHandler(bookingController.listBookings));

router.get('/:id', asyncHandler(bookingController.getBooking));

router.put('/:id/confirm', authenticateToken, asyncHandler(bookingController.confirmBooking));

router.put('/:id/cancel', authenticateToken, asyncHandler(bookingController.cancelBooking));

router.post(
  '/:id/rate',
  authenticateToken,
  [
    body('score').isInt({ min: 1, max: 5 }).withMessage('Score must be 1-5'),
    body('comment').optional().trim(),
  ],
  asyncHandler(bookingController.createRating)
);

router.put(
  '/:id/pickup-location',
  authenticateToken,
  [
    body('lat').isFloat({ min: -90, max: 90 }).withMessage('Latitude must be between -90 and 90'),
    body('lng').isFloat({ min: -180, max: 180 }).withMessage('Longitude must be between -180 and 180'),
    body('address').optional().trim(),
  ],
  asyncHandler(bookingController.updatePickupLocation)
);

router.get(
  '/trips/:tripId/bookings',
  authenticateToken,
  asyncHandler(bookingController.getTripBookings)
);

router.get(
  '/trip/:tripId',
  authenticateToken,
  asyncHandler(bookingController.getTripBookings)
);

export default router;
