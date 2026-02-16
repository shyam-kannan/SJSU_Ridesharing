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

export default router;
