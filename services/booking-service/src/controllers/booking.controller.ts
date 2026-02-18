import { Response } from 'express';
import axios from 'axios';
import * as bookingService from '../services/booking.service';
import { AuthRequest, AppError, successResponse, errorResponse, CreateBookingRequest, CreateRatingRequest } from '@lessgo/shared';
import { config } from '../config';

// Fire-and-forget email notification (never throws)
async function fireEmail(path: string, body: object): Promise<void> {
  try {
    await axios.post(`${config.notificationServiceUrl}${path}`, body);
  } catch {
    // Non-critical — log and continue
    console.log(`[EMAIL] Notification to ${path} failed (non-critical)`);
  }
}

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

    // Fire email notifications (non-blocking)
    if (booking.rider && booking.trip) {
      const depTime = new Date(booking.trip.departure_time).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' });
      const amount = booking.quote?.max_price ?? 0;

      // Email to rider
      fireEmail('/notifications/send/booking-confirmation', {
        email: booking.rider.email,
        riderName: booking.rider.name,
        origin: booking.trip.origin,
        destination: booking.trip.destination,
        departureTime: depTime,
        seats: booking.seats_booked,
        amount,
        bookingId: booking.booking_id,
      });
    }
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

    // Fire cancellation email (non-blocking)
    if (booking.rider && booking.trip) {
      const depTime = new Date(booking.trip.departure_time).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' });
      const refundAmount = booking.payment?.amount;

      fireEmail('/notifications/send/cancellation', {
        email: booking.rider.email,
        name: booking.rider.name,
        origin: booking.trip.origin,
        destination: booking.trip.destination,
        departureTime: depTime,
        refundAmount,
        bookingId: booking.booking_id,
      });
    }
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
