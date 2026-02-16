import { Request, Response } from 'express';
import Stripe from 'stripe';
import * as paymentService from '../services/payment.service';
import { successResponse, errorResponse, AppError } from '@lessgo/shared';

/**
 * Determine HTTP status code from error type
 */
function getErrorStatus(error: unknown): number {
  // Stripe API errors
  if (error instanceof Stripe.errors.StripeError) {
    switch (error.type) {
      case 'StripeCardError': return 400;
      case 'StripeInvalidRequestError': return 400;
      case 'StripeAuthenticationError': return 502;
      case 'StripeRateLimitError': return 429;
      case 'StripeConnectionError': return 502;
      default: return 502;
    }
  }

  // DB FK constraint violation (booking_id doesn't exist)
  if (error instanceof Error && 'code' in error && (error as any).code === '23503') {
    return 400;
  }

  // Application-level errors (duplicate payment, not found, etc.)
  if (error instanceof Error) {
    if (error.message.includes('already exists')) return 409;
    if (error.message.includes('not found') || error.message.includes('Not found')) return 404;
    if (error.message.includes('Can only refund')) return 400;
    if (error.message.includes('Can only cancel')) return 400;
  }

  return 500;
}

/**
 * Get a user-friendly error message
 */
function getErrorMessage(error: unknown): string {
  if (error instanceof Stripe.errors.StripeError) {
    console.error(`Stripe error [${error.type}]:`, error.message);
    return `Payment processing error: ${error.message}`;
  }

  if (error instanceof Error && 'code' in error && (error as any).code === '23503') {
    console.error('FK constraint violation:', (error as any).detail);
    return 'Invalid booking_id: booking does not exist';
  }

  if (error instanceof Error) {
    return error.message;
  }

  return 'An unexpected error occurred';
}

export const createIntent = async (req: Request, res: Response): Promise<void> => {
  try {
    const { booking_id, amount } = req.body;
    const payment = await paymentService.createPaymentIntent(booking_id, amount);
    successResponse(res, payment, 'Payment intent created', 201);
  } catch (error) {
    console.error('Create payment intent error:', error);
    const status = getErrorStatus(error);
    errorResponse(res, getErrorMessage(error), status);
  }
};

export const capture = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const payment = await paymentService.capturePayment(id);
    successResponse(res, payment, 'Payment captured successfully');
  } catch (error) {
    console.error('Capture payment error:', error);
    const status = getErrorStatus(error);
    errorResponse(res, getErrorMessage(error), status);
  }
};

export const refund = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const payment = await paymentService.refundPayment(id);
    successResponse(res, payment, 'Payment refunded successfully');
  } catch (error) {
    console.error('Refund payment error:', error);
    const status = getErrorStatus(error);
    errorResponse(res, getErrorMessage(error), status);
  }
};

export const cancel = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const payment = await paymentService.cancelPayment(id);
    successResponse(res, payment, 'Payment cancelled successfully');
  } catch (error) {
    console.error('Cancel payment error:', error);
    const status = getErrorStatus(error);
    errorResponse(res, getErrorMessage(error), status);
  }
};

export const getByBooking = async (req: Request, res: Response): Promise<void> => {
  try {
    const { bookingId } = req.params;
    const payment = await paymentService.getPaymentByBooking(bookingId);
    if (!payment) {
      errorResponse(res, 'Payment not found', 404);
      return;
    }
    successResponse(res, payment, 'Payment retrieved successfully');
  } catch (error) {
    console.error('Get payment error:', error);
    throw new AppError('Failed to get payment', 500);
  }
};
