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

      // Email to driver
      if (booking.trip.driver) {
        fireEmail('/notifications/send/driver-new-booking', {
          email: booking.trip.driver.email,
          driverName: booking.trip.driver.name,
          riderName: booking.rider.name,
          origin: booking.trip.origin,
          destination: booking.trip.destination,
          departureTime: depTime,
          seatsBooked: booking.seats_booked,
        });
      }
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

export const updatePickupLocation = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const { id } = req.params;
    const { lat, lng, address } = req.body;

    if (typeof lat !== 'number' || typeof lng !== 'number') {
      errorResponse(res, 'lat and lng are required and must be numbers', 400);
      return;
    }

    const booking = await bookingService.updatePickupLocation(
      id,
      req.user.userId,
      { lat, lng, address }
    );

    successResponse(res, booking, 'Pickup location updated successfully');
  } catch (error) {
    console.error('Update pickup location error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to update pickup location', 500);
  }
};

export const getTripBookings = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const { tripId } = req.params;

    // Verify user owns this trip by calling trip-service
    try {
      const tripResponse = await axios.get(`${config.tripServiceUrl}/trips/${tripId}`, {
        headers: { Authorization: req.headers.authorization }
      });

      const trip = tripResponse.data.data;

      if (trip.driver_id !== req.user.userId) {
        errorResponse(res, 'Unauthorized: You must be the driver of this trip', 403);
        return;
      }
    } catch (error) {
      if (axios.isAxiosError(error) && error.response?.status === 404) {
        errorResponse(res, 'Trip not found', 404);
        return;
      }
      throw error;
    }

    // Get all bookings for this trip
    const bookings = await bookingService.getBookingsByTripId(tripId);

    successResponse(res, bookings, 'Trip bookings retrieved successfully');
  } catch (error) {
    console.error('Get trip bookings error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to get trip bookings', 500);
  }
};
