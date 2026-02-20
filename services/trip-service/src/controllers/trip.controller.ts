import { Response } from 'express';
import axios from 'axios';
import * as tripService from '../services/trip.service';
import { AuthRequest, AppError, successResponse, errorResponse, CreateTripRequest, SearchTripsRequest, TripStatus } from '@lessgo/shared';
import { config } from '../config';

/**
 * Create a new trip
 * POST /trips
 */
export const createTrip = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    // Verify user is a driver
    if (req.user.role !== 'Driver') {
      errorResponse(res, 'Only drivers can create trips', 403);
      return;
    }

    const tripData: CreateTripRequest = req.body;

    const trip = await tripService.createTrip(req.user.userId, tripData);

    successResponse(res, trip, 'Trip created successfully', 201);
  } catch (error) {
    console.error('Create trip error:', error);
    if (error instanceof Error && error.message.includes('Geocoding')) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to create trip', 500);
  }
};

/**
 * Get trip by ID
 * GET /trips/:id
 */
export const getTrip = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const trip = await tripService.getTripById(id);

    if (!trip) {
      errorResponse(res, 'Trip not found', 404);
      return;
    }

    successResponse(res, trip, 'Trip retrieved successfully');
  } catch (error) {
    console.error('Get trip error:', error);
    throw new AppError('Failed to get trip', 500);
  }
};

/**
 * Search for trips near a location
 * GET /trips/search
 */
export const searchTrips = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const {
      origin_lat,
      origin_lng,
      radius_meters,
      min_seats,
      departure_after,
      departure_before,
    } = req.query;

    // Validate required parameters
    if (!origin_lat || !origin_lng) {
      errorResponse(res, 'origin_lat and origin_lng are required', 400);
      return;
    }

    const lat = parseFloat(origin_lat as string);
    const lng = parseFloat(origin_lng as string);

    if (isNaN(lat) || isNaN(lng)) {
      errorResponse(res, 'Invalid coordinates', 400);
      return;
    }

    const radius = radius_meters
      ? Math.min(parseFloat(radius_meters as string), config.maxSearchRadius)
      : config.defaultSearchRadius;

    const filters: any = {};

    if (min_seats) {
      filters.minSeats = parseInt(min_seats as string);
    }

    if (departure_after) {
      filters.departureAfter = new Date(departure_after as string);
    }

    if (departure_before) {
      filters.departureBefore = new Date(departure_before as string);
    }

    const trips = await tripService.searchTripsNearby(lat, lng, radius, filters);

    successResponse(
      res,
      {
        trips,
        search_params: {
          origin: { lat, lng },
          radius_meters: radius,
          filters,
        },
        total: trips.length,
      },
      'Trips found successfully'
    );
  } catch (error) {
    console.error('Search trips error:', error);
    throw new AppError('Failed to search trips', 500);
  }
};

/**
 * List trips with filters
 * GET /trips
 */
export const listTrips = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { driver_id, status, departure_after, limit } = req.query;

    const filters: any = {};

    if (driver_id) {
      filters.driverId = driver_id as string;
    }

    if (status) {
      if (!Object.values(TripStatus).includes(status as TripStatus)) {
        errorResponse(res, 'Invalid status', 400);
        return;
      }
      filters.status = status as TripStatus;
    }

    if (departure_after) {
      filters.departureAfter = new Date(departure_after as string);
    }

    if (limit) {
      filters.limit = parseInt(limit as string);
    }

    const trips = await tripService.listTrips(filters);

    successResponse(res, { trips, total: trips.length }, 'Trips retrieved successfully');
  } catch (error) {
    console.error('List trips error:', error);
    throw new AppError('Failed to list trips', 500);
  }
};

/**
 * Update trip
 * PUT /trips/:id
 */
export const updateTrip = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const updates = req.body;

    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const trip = await tripService.updateTrip(id, req.user.userId, updates);

    successResponse(res, trip, 'Trip updated successfully');
  } catch (error) {
    console.error('Update trip error:', error);
    if (error instanceof Error && error.message === 'Trip not found') {
      errorResponse(res, 'Trip not found', 404);
      return;
    }
    if (error instanceof Error && error.message === 'Unauthorized') {
      errorResponse(res, 'You can only update your own trips', 403);
      return;
    }
    if (error instanceof Error && error.message === 'No fields to update') {
      errorResponse(res, 'No fields to update', 400);
      return;
    }
    throw new AppError('Failed to update trip', 500);
  }
};

/**
 * Cancel trip
 * DELETE /trips/:id
 */
export const cancelTrip = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    const trip = await tripService.cancelTrip(id, req.user.userId);

    successResponse(res, trip, 'Trip cancelled successfully');
  } catch (error) {
    console.error('Cancel trip error:', error);
    if (error instanceof Error && error.message === 'Trip not found') {
      errorResponse(res, 'Trip not found', 404);
      return;
    }
    if (error instanceof Error && error.message === 'Unauthorized') {
      errorResponse(res, 'You can only cancel your own trips', 403);
      return;
    }
    throw new AppError('Failed to cancel trip', 500);
  }
};

/**
 * Get all bookings for a trip (passengers list)
 * GET /trips/:id/bookings
 */
export const getTripBookings = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    // Verify user owns this trip
    const trip = await tripService.getTripById(id);

    if (!trip) {
      errorResponse(res, 'Trip not found', 404);
      return;
    }

    if (trip.driver_id !== req.user.userId) {
      errorResponse(res, 'Unauthorized: You must be the driver of this trip', 403);
      return;
    }

    // Fetch bookings from booking-service
    try {
      const bookingsResponse = await axios.get(
        `${config.bookingServiceUrl}/bookings/trip/${id}`,
        {
          headers: { Authorization: req.headers.authorization }
        }
      );

      const bookings = bookingsResponse.data.data || [];

      successResponse(res, { bookings, total: bookings.length }, 'Trip bookings retrieved successfully');
    } catch (error) {
      if (axios.isAxiosError(error)) {
        console.error('Error fetching bookings from booking-service:', error.message);
        // Return empty list if booking service fails
        successResponse(res, { bookings: [], total: 0 }, 'Trip bookings retrieved successfully');
      } else {
        throw error;
      }
    }
  } catch (error) {
    console.error('Get trip bookings error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to get trip bookings', 500);
  }
};
