import { Response } from 'express';
import * as bookingService from '../services/booking.service';
import { AuthRequest } from '../../../shared/middleware/auth';
import { AppError } from '../../../shared/middleware/errorHandler';
import { successResponse, errorResponse } from '../../../shared/utils/response';
import { CreateBookingRequest, CreateRatingRequest } from '../../../shared/types';

export const createBooking = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const bookingData: CreateBookingRequest = req.body;
    const result = await bookingService.createBooking(req.user.userId, bookingData);

    successResponse(res, result, 'Booking created successfully', 201);
  } catch (error) {
    console.error('Create booking error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to create booking', 500);
  }
};

export const getBooking = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const booking = await bookingService.getBookingById(id);

    if (!booking) {
      errorResponse(res, 'Booking not found', 404);
      return;
    }

    successResponse(res, booking, 'Booking retrieved successfully');
  } catch (error) {
    console.error('Get booking error:', error);
    throw new AppError('Failed to get booking', 500);
  }
};

export const listBookings = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const asDriver = req.query.as_driver === 'true';
    const bookings = await bookingService.listUserBookings(req.user.userId, asDriver);

    successResponse(res, { bookings, total: bookings.length }, 'Bookings retrieved successfully');
  } catch (error) {
    console.error('List bookings error:', error);
    throw new AppError('Failed to list bookings', 500);
  }
};

export const confirmBooking = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const { id } = req.params;
    const booking = await bookingService.confirmBooking(id, req.user.userId);

    successResponse(res, booking, 'Booking confirmed successfully');
  } catch (error) {
    console.error('Confirm booking error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to confirm booking', 500);
  }
};

export const cancelBooking = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const { id } = req.params;
    const booking = await bookingService.cancelBooking(id, req.user.userId);

    successResponse(res, booking, 'Booking cancelled successfully');
  } catch (error) {
    console.error('Cancel booking error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to cancel booking', 500);
  }
};

export const createRating = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const { id } = req.params;
    const ratingData: CreateRatingRequest = req.body;

    const rating = await bookingService.createRating(id, req.user.userId, ratingData);

    successResponse(res, rating, 'Rating created successfully', 201);
  } catch (error) {
    console.error('Create rating error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to create rating', 500);
  }
};
