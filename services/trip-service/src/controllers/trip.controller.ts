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

    // Verify driver has complete vehicle profile
    try {
      const userResponse = await axios.get(
        `${config.userServiceUrl}/users/${req.user.userId}`,
        { headers: { Authorization: req.headers.authorization } }
      );

      const driver = userResponse.data.data;

      if (!driver.vehicle_info || !driver.seats_available || !driver.license_plate) {
        errorResponse(res, 'Please complete your driver profile before creating trips', 400);
        return;
      }
    } catch (error) {
      console.error('Failed to fetch driver details:', error);
      errorResponse(res, 'Failed to verify driver profile', 500);
      return;
    }

    const tripData: CreateTripRequest = req.body;

    const trip = await tripService.createTrip(req.user.userId, tripData);

    successResponse(res, trip, 'Trip created successfully', 201);
  } catch (error) {
    console.error('Create trip error:', error);
    if (error instanceof Error) {
      const msg = error.message;
      const lower = msg.toLowerCase();

      if (lower.includes('geocod')) {
        errorResponse(res, msg, lower.includes('api key') ? 500 : 400);
        return;
      }

      if (lower.includes('already have a trip scheduled') || lower.includes('choose a different time')) {
        errorResponse(res, msg, 409);
        return;
      }

      if (lower.includes('postgis') || lower.includes('st_setsrid') || lower.includes('st_makepoint')) {
        errorResponse(res, 'Trip database geospatial support is not configured (PostGIS)', 500);
        return;
      }

      // Surface actionable backend errors instead of a generic 500 wrapper.
      if (msg.length < 160) {
        errorResponse(res, msg, 500);
        return;
      }
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
    const bookingsResponse = await axios.get(
      `${config.bookingServiceUrl}/bookings/trip/${id}`,
      {
        headers: { Authorization: req.headers.authorization }
      }
    );

    const bookings = bookingsResponse.data.data || [];

    successResponse(res, { bookings, total: bookings.length }, 'Trip bookings retrieved successfully');
  } catch (error) {
    console.error('Get trip bookings error:', error);
    if (axios.isAxiosError(error)) {
      const status = error.response?.status ?? 502;
      const message =
        (error.response?.data as any)?.message ||
        'Failed to retrieve trip bookings from booking service';
      errorResponse(res, message, status);
      return;
    }
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to get trip bookings', 500);
  }
};

/**
 * Update trip state (for real-time ride tracking)
 * PUT /trips/:id/state
 */
export const updateTripState = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    // Validate status
    const validStates = ['pending', 'en_route', 'arrived', 'in_progress', 'completed', 'cancelled'];
    if (!validStates.includes(status)) {
      errorResponse(res, 'Invalid trip status', 400);
      return;
    }

    // Get trip to verify ownership
    const trip = await tripService.getTripById(id);

    if (!trip) {
      errorResponse(res, 'Trip not found', 404);
      return;
    }

    // Only driver can update trip state
    if (trip.driver_id !== req.user.userId) {
      errorResponse(res, 'Only the trip driver can update the trip state', 403);
      return;
    }

    const updatedTrip = await tripService.updateTripState(id, status as TripStatus);

    console.log(`🚗 Trip ${id} state updated to: ${status}`);

    // Notify riders on major trip state changes
    try {
      const bookingsResponse = await axios.get(
        `${config.bookingServiceUrl}/bookings/trip/${id}`,
        { headers: { Authorization: req.headers.authorization } }
      );
      const bookings = bookingsResponse.data.data || [];
      const riderIds = bookings
        .map((b: any) => b.rider_id)
        .filter((v: any): v is string => typeof v === 'string');

      const statusTitleMap: Record<string, string> = {
        en_route: 'Driver Is On The Way',
        arrived: 'Driver Arrived',
        in_progress: 'Trip Started',
        completed: 'Trip Completed',
        cancelled: 'Trip Cancelled',
      };
      const statusMessageMap: Record<string, string> = {
        en_route: `Your driver is heading to pickup for ${trip.destination}`,
        arrived: 'Your driver has arrived at the pickup location',
        in_progress: 'Your trip is now in progress',
        completed: 'Your trip has been completed',
        cancelled: 'This trip was cancelled by the driver',
      };

      if (statusTitleMap[status]) {
        await Promise.all(
          riderIds.map((userId: string) =>
            fireInAppNotification({
              user_id: userId,
              type: 'trip_status',
              title: statusTitleMap[status],
              message: statusMessageMap[status] || `Trip status updated to ${status}`,
              data: { trip_id: id, status },
            })
          )
        );
      }
    } catch (notifyErr) {
      console.error('Trip state notification error (non-critical):', notifyErr);
    }

    successResponse(res, updatedTrip, 'Trip state updated successfully');
  } catch (error) {
    console.error('Update trip state error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to update trip state', 500);
  }
};

/**
 * Update driver location for active trip
 * POST /trips/:id/location
 */
export const updateTripLocation = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { latitude, longitude, heading, speed, accuracy } = req.body;

    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    // Validate location data
    if (latitude === undefined || longitude === undefined) {
      errorResponse(res, 'Latitude and longitude are required', 400);
      return;
    }

    // Get trip to verify ownership
    const trip = await tripService.getTripById(id);

    if (!trip) {
      errorResponse(res, 'Trip not found', 404);
      return;
    }

    // Only driver can update location
    if (trip.driver_id !== req.user.userId) {
      errorResponse(res, 'Only the trip driver can update location', 403);
      return;
    }

    // Save location
    await tripService.updateTripLocation(id, req.user.userId, {
      latitude,
      longitude,
      heading,
      speed,
      accuracy,
    });

    successResponse(res, { updated: true }, 'Location updated successfully');
  } catch (error) {
    console.error('Update trip location error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to update trip location', 500);
  }
};

/**
 * Get latest driver location for trip
 * GET /trips/:id/location
 */
export const getTripLocation = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;

    const location = await tripService.getTripLocation(id);

    if (!location) {
      errorResponse(res, 'No location data available for this trip', 404);
      return;
    }

    successResponse(res, location, 'Location retrieved successfully');
  } catch (error) {
    console.error('Get trip location error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to get trip location', 500);
  }
};

/**
 * Send a message in trip chat
 * POST /trips/:id/messages
 */
export const sendMessage = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { message } = req.body;

    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      errorResponse(res, 'Message text is required', 400);
      return;
    }

    // Verify user is part of this trip (driver or rider with booking)
    const trip = await tripService.getTripById(id);

    if (!trip) {
      errorResponse(res, 'Trip not found', 404);
      return;
    }

    // Check if user is the driver
    const isDriver = trip.driver_id === req.user.userId;

    // If not driver, check if user has a booking for this trip
    let isRider = false;
    if (!isDriver) {
      isRider = await riderHasBookingForTrip(req.headers.authorization, id, req.user.userId);
    }

    if (!isDriver && !isRider) {
      errorResponse(res, 'You must be the driver or a rider of this trip to send messages', 403);
      return;
    }

    const newMessage = await tripService.sendMessage(id, req.user.userId, message.trim());

    console.log(`💬 Message sent in trip ${id} by user ${req.user.userId}`);

    // Notify other trip participants about the new chat message
    try {
      const recipients = new Set<string>();
      let senderName = 'Someone';

      if (isDriver) {
        const bookingsResponse = await axios.get(
          `${config.bookingServiceUrl}/bookings/trip/${id}`,
          { headers: { Authorization: req.headers.authorization } }
        );
        const bookings = extractBookingsArray(bookingsResponse.data);

        senderName = trip.driver?.name || 'Driver';
        for (const booking of bookings) {
          if (booking?.rider_id && booking.rider_id !== req.user.userId) recipients.add(booking.rider_id);
        }
      } else {
        senderName = 'Rider';
        try {
          const riderBookingsResponse = await axios.get(
            `${config.bookingServiceUrl}/bookings`,
            { headers: { Authorization: req.headers.authorization } }
          );
          const riderBookings = extractBookingsArray(riderBookingsResponse.data);
          const riderBooking = riderBookings.find((b: any) => {
            const bookingTripId = b?.trip_id ?? b?.trip?.trip_id ?? b?.trip?.id;
            return bookingTripId === id;
          });
          senderName =
            riderBooking?.rider_name ??
            riderBooking?.rider?.name ??
            riderBooking?.trip?.rider?.name ??
            'Rider';
        } catch (nameErr) {
          console.error('Failed to resolve rider sender name for chat notification:', nameErr);
        }

        if (trip.driver_id && trip.driver_id !== req.user.userId) recipients.add(trip.driver_id);
      }

      const preview = message.trim().slice(0, 80);
      await Promise.all(
        Array.from(recipients).map((userId) =>
          fireInAppNotification({
            user_id: userId,
            type: 'chat_message',
            title: `New message from ${senderName}`,
            message: preview,
            data: { trip_id: id, sender_id: req.user?.userId },
          })
        )
      );
    } catch (notifyErr) {
      console.error('Chat notification error (non-critical):', notifyErr);
    }

    successResponse(res, newMessage, 'Message sent successfully', 201);
  } catch (error) {
    console.error('Send message error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to send message', 500);
  }
};

/**
 * Get messages for a trip
 * GET /trips/:id/messages
 */
export const getTripMessages = async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { limit } = req.query;

    if (!req.user) {
      errorResponse(res, 'Authentication required', 401);
      return;
    }

    // Verify user is part of this trip
    const trip = await tripService.getTripById(id);

    if (!trip) {
      errorResponse(res, 'Trip not found', 404);
      return;
    }

    const isDriver = trip.driver_id === req.user.userId;

    let isRider = false;
    if (!isDriver) {
      isRider = await riderHasBookingForTrip(req.headers.authorization, id, req.user.userId);
    }

    if (!isDriver && !isRider) {
      errorResponse(res, 'You must be the driver or a rider of this trip to view messages', 403);
      return;
    }

    const messages = await tripService.getTripMessages(id, limit ? parseInt(limit as string) : 100);

    // Mark messages as read for this user
    await tripService.markMessagesAsRead(id, req.user.userId);

    successResponse(res, { messages, total: messages.length }, 'Messages retrieved successfully');
  } catch (error) {
    console.error('Get messages error:', error);
    if (error instanceof Error) {
      errorResponse(res, error.message, 400);
      return;
    }
    throw new AppError('Failed to get messages', 500);
  }
};
async function fireInAppNotification(body: {
  user_id: string;
  type: string;
  title: string;
  message: string;
  data?: object;
}): Promise<void> {
  try {
    await axios.post(`${config.notificationServiceUrl}/notifications/send`, body);
  } catch {
    console.log(`[NOTIFICATION] In-app notification failed (non-critical) for user ${body.user_id}`);
  }
}

function extractBookingsArray(payload: any): any[] {
  const data = payload?.data;
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.bookings)) return data.bookings;
  return [];
}

async function riderHasBookingForTrip(authHeader: string | undefined, tripId: string, userId: string): Promise<boolean> {
  try {
    const bookingsResponse = await axios.get(
      `${config.bookingServiceUrl}/bookings`,
      { headers: { Authorization: authHeader } }
    );
    const bookings = extractBookingsArray(bookingsResponse.data);
    return bookings.some((b: any) => {
      const bookingTripId = b?.trip_id ?? b?.trip?.trip_id ?? b?.trip?.id;
      const bookingRiderId = b?.rider_id ?? b?.riderId ?? b?.rider?.user_id ?? b?.rider?.id;
      return bookingTripId === tripId && bookingRiderId === userId;
    });
  } catch (error) {
    console.error('Failed to verify rider booking via user bookings:', error);
    return false;
  }
}
