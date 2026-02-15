import { Request, Response } from 'express';
import * as paymentService from '../services/payment.service';
import { successResponse, errorResponse } from '../../../shared/utils/response';
import { AppError } from '../../../shared/middleware/errorHandler';

export const createIntent = async (req: Request, res: Response): Promise<void> => {
  try {
    const { booking_id, amount } = req.body;
    const payment = await paymentService.createPaymentIntent(booking_id, amount);
    successResponse(res, payment, 'Payment intent created', 201);
  } catch (error) {
    console.error('Create payment intent error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to create payment intent', 500);
  }
};

export const capture = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const payment = await paymentService.capturePayment(id);
    successResponse(res, payment, 'Payment captured successfully');
  } catch (error) {
    console.error('Capture payment error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to capture payment', 500);
  }
};

export const refund = async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const payment = await paymentService.refundPayment(id);
    successResponse(res, payment, 'Payment refunded successfully');
  } catch (error) {
    console.error('Refund payment error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to refund payment', 500);
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
