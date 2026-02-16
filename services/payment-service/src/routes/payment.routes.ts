import express from 'express';
import { Request, Response, NextFunction } from 'express';
import * as paymentController from '../controllers/payment.controller';
import { asyncHandler } from '@lessgo/shared';
import { body, validationResult } from 'express-validator';

const router = express.Router();

/** Check express-validator results and return 400 if invalid */
const validate = (req: Request, res: Response, next: NextFunction): void => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({
      status: 'error',
      message: 'Validation failed',
      errors: errors.array(),
    });
    return;
  }
  next();
};

router.post(
  '/create-intent',
  [
    body('booking_id').notEmpty().withMessage('booking_id is required').isUUID().withMessage('booking_id must be a valid UUID'),
    body('amount').notEmpty().withMessage('amount is required').isFloat({ min: 0.01 }).withMessage('amount must be greater than 0'),
    validate,
  ],
  asyncHandler(paymentController.createIntent)
);

router.post('/:id/capture', asyncHandler(paymentController.capture));
router.post('/:id/cancel', asyncHandler(paymentController.cancel));
router.post('/:id/refund', asyncHandler(paymentController.refund));
router.get('/booking/:bookingId', asyncHandler(paymentController.getByBooking));

export default router;
