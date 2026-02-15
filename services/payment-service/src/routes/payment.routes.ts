import express from 'express';
import * as paymentController from '../controllers/payment.controller';
import { asyncHandler } from '../../../shared/middleware/errorHandler';
import { body } from 'express-validator';

const router = express.Router();

router.post(
  '/create-intent',
  [
    body('booking_id').notEmpty().isUUID(),
    body('amount').notEmpty().isFloat({ min: 0.01 }),
  ],
  asyncHandler(paymentController.createIntent)
);

router.post('/:id/capture', asyncHandler(paymentController.capture));
router.post('/:id/refund', asyncHandler(paymentController.refund));
router.get('/booking/:bookingId', asyncHandler(paymentController.getByBooking));

export default router;
