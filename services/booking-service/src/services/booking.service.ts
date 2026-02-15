import { Pool } from 'pg';
import axios from 'axios';
import { config } from '../config';
import {
  Booking,
  BookingWithDetails,
  BookingStatus,
  Quote,
  Rating,
  CreateBookingRequest,
  CreateRatingRequest,
} from '../../../shared/types';

const pool = new Pool({
  connectionString: config.databaseUrl,
});

/**
 * Create a new booking
 * @param riderId Rider's UUID
 * @param bookingData Booking creation data
 * @returns Created booking with quote
 */
export const createBooking = async (
  riderId: string,
  bookingData: CreateBookingRequest
): Promise<{ booking: Booking; quote: Quote }> => {
  const { trip_id, seats_booked } = bookingData;

  // Check trip availability
  const tripQuery = `
    SELECT trip_id, driver_id, origin, destination, seats_available, status
    FROM trips
    WHERE trip_id = $1
  `;
  const tripResult = await pool.query(tripQuery, [trip_id]);

  if (tripResult.rows.length === 0) {
    throw new Error('Trip not found');
  }

  const trip = tripResult.rows[0];

  if (trip.status !== 'active') {
    throw new Error('Trip is not active');
  }

  if (trip.seats_available < seats_booked) {
    throw new Error('Not enough seats available');
  }

  // Prevent driver from booking own trip
  if (trip.driver_id === riderId) {
    throw new Error('Drivers cannot book their own trips');
  }

  // Create booking
  const bookingQuery = `
    INSERT INTO bookings (trip_id, rider_id, seats_booked, status)
    VALUES ($1, $2, $3, $4)
    RETURNING *
  `;
  const bookingResult = await pool.query(bookingQuery, [
    trip_id,
    riderId,
    seats_booked,
    BookingStatus.Pending,
  ]);
  const booking = bookingResult.rows[0];

  // Generate quote via Cost Calculation Service
  try {
    const costResponse = await axios.post(`${config.costServiceUrl}/cost/calculate`, {
      origin: trip.origin,
      destination: trip.destination,
      num_riders: seats_booked,
      trip_id: trip_id,
    });

    const maxPrice = costResponse.data.data.max_price;

    // Create quote
    const quoteQuery = `
      INSERT INTO quotes (booking_id, max_price)
      VALUES ($1, $2)
      RETURNING *
    `;
    const quoteResult = await pool.query(quoteQuery, [booking.booking_id, maxPrice]);
    const quote = quoteResult.rows[0];

    return { booking, quote };
  } catch (error) {
    // If cost service fails, delete booking and throw error
    await pool.query('DELETE FROM bookings WHERE booking_id = $1', [booking.booking_id]);
    console.error('Cost calculation failed:', error);
    throw new Error('Failed to generate quote. Booking cancelled.');
  }
};

/**
 * Get booking by ID with details
 * @param bookingId Booking's UUID
 * @returns Booking with trip, rider, quote, and payment details
 */
export const getBookingById = async (bookingId: string): Promise<BookingWithDetails | null> => {
  const query = `
    SELECT
      b.*,
      t.trip_id, t.driver_id, t.origin, t.destination,
      ST_X(t.origin_point::geometry) as origin_lng,
      ST_Y(t.origin_point::geometry) as origin_lat,
      ST_X(t.destination_point::geometry) as destination_lng,
      ST_Y(t.destination_point::geometry) as destination_lat,
      t.departure_time, t.seats_available as trip_seats_available, t.recurrence, t.status as trip_status,
      t.created_at as trip_created_at, t.updated_at as trip_updated_at,
      r.user_id as rider_user_id, r.name as rider_name, r.email as rider_email,
      r.role as rider_role, r.sjsu_id_status as rider_sjsu_id_status, r.rating as rider_rating,
      r.created_at as rider_created_at, r.updated_at as rider_updated_at,
      q.quote_id, q.max_price, q.final_price, q.created_at as quote_created_at,
      p.payment_id, p.stripe_payment_intent_id, p.amount, p.status as payment_status,
      p.created_at as payment_created_at, p.updated_at as payment_updated_at
    FROM bookings b
    JOIN trips t ON b.trip_id = t.trip_id
    JOIN users r ON b.rider_id = r.user_id
    LEFT JOIN quotes q ON b.booking_id = q.booking_id
    LEFT JOIN payments p ON b.booking_id = p.booking_id
    WHERE b.booking_id = $1
  `;

  const result = await pool.query(query, [bookingId]);

  if (result.rows.length === 0) {
    return null;
  }

  const row = result.rows[0];

  return {
    booking_id: row.booking_id,
    trip_id: row.trip_id,
    rider_id: row.rider_id,
    status: row.status,
    seats_booked: row.seats_booked,
    created_at: row.created_at,
    updated_at: row.updated_at,
    trip: {
      trip_id: row.trip_id,
      driver_id: row.driver_id,
      origin: row.origin,
      destination: row.destination,
      origin_point: { lat: row.origin_lat, lng: row.origin_lng },
      destination_point: { lat: row.destination_lat, lng: row.destination_lng },
      departure_time: row.departure_time,
      seats_available: row.trip_seats_available,
      recurrence: row.recurrence,
      status: row.trip_status,
      created_at: row.trip_created_at,
      updated_at: row.trip_updated_at,
    },
    rider: {
      user_id: row.rider_user_id,
      name: row.rider_name,
      email: row.rider_email,
      role: row.rider_role,
      sjsu_id_status: row.rider_sjsu_id_status,
      rating: row.rider_rating,
      created_at: row.rider_created_at,
      updated_at: row.rider_updated_at,
    },
    quote: row.quote_id ? {
      quote_id: row.quote_id,
      booking_id: row.booking_id,
      max_price: parseFloat(row.max_price),
      final_price: row.final_price ? parseFloat(row.final_price) : undefined,
      created_at: row.quote_created_at,
    } : undefined,
    payment: row.payment_id ? {
      payment_id: row.payment_id,
      booking_id: row.booking_id,
      stripe_payment_intent_id: row.stripe_payment_intent_id,
      amount: parseFloat(row.amount),
      status: row.payment_status,
      created_at: row.payment_created_at,
      updated_at: row.payment_updated_at,
    } : undefined,
  };
};

/**
 * List user's bookings (as rider or driver)
 * @param userId User's UUID
 * @param asDriver Whether to list as driver
 * @returns Array of bookings
 */
export const listUserBookings = async (
  userId: string,
  asDriver: boolean = false
): Promise<BookingWithDetails[]> => {
  const query = asDriver
    ? `SELECT b.booking_id FROM bookings b JOIN trips t ON b.trip_id = t.trip_id WHERE t.driver_id = $1 ORDER BY b.created_at DESC`
    : `SELECT booking_id FROM bookings WHERE rider_id = $1 ORDER BY created_at DESC`;

  const result = await pool.query(query, [userId]);

  const bookings = await Promise.all(
    result.rows.map((row) => getBookingById(row.booking_id))
  );

  return bookings.filter((b) => b !== null) as BookingWithDetails[];
};

/**
 * Confirm booking with payment
 * @param bookingId Booking's UUID
 * @param userId User's UUID (for authorization)
 * @returns Updated booking with payment
 */
export const confirmBooking = async (
  bookingId: string,
  userId: string
): Promise<BookingWithDetails> => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Get booking
    const bookingData = await getBookingById(bookingId);
    if (!bookingData) {
      throw new Error('Booking not found');
    }

    // Verify user is the rider
    if (bookingData.rider_id !== userId) {
      throw new Error('Unauthorized');
    }

    if (bookingData.status !== BookingStatus.Pending) {
      throw new Error('Booking is not pending');
    }

    if (!bookingData.quote) {
      throw new Error('Quote not found');
    }

    // Create payment via Payment Service
    const paymentResponse = await axios.post(`${config.paymentServiceUrl}/payments/create-intent`, {
      booking_id: bookingId,
      amount: bookingData.quote.max_price,
    });

    const payment = paymentResponse.data.data;

    // Update booking status
    await client.query(
      'UPDATE bookings SET status = $1, updated_at = current_timestamp WHERE booking_id = $2',
      [BookingStatus.Confirmed, bookingId]
    );

    // Reduce trip seats
    await client.query(
      'UPDATE trips SET seats_available = seats_available - $1, updated_at = current_timestamp WHERE trip_id = $2',
      [bookingData.seats_booked, bookingData.trip_id]
    );

    await client.query('COMMIT');

    // Return updated booking
    const updatedBooking = await getBookingById(bookingId);
    return updatedBooking!;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Cancel booking (with refund if confirmed)
 * @param bookingId Booking's UUID
 * @param userId User's UUID (for authorization)
 * @returns Updated booking
 */
export const cancelBooking = async (
  bookingId: string,
  userId: string
): Promise<BookingWithDetails> => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const bookingData = await getBookingById(bookingId);
    if (!bookingData) {
      throw new Error('Booking not found');
    }

    // Verify user is the rider
    if (bookingData.rider_id !== userId) {
      throw new Error('Unauthorized');
    }

    if (bookingData.status === BookingStatus.Cancelled) {
      throw new Error('Booking already cancelled');
    }

    if (bookingData.status === BookingStatus.Completed) {
      throw new Error('Cannot cancel completed booking');
    }

    // If confirmed, issue refund
    if (bookingData.status === BookingStatus.Confirmed && bookingData.payment) {
      await axios.post(`${config.paymentServiceUrl}/payments/${bookingData.payment.payment_id}/refund`);
    }

    // Update booking status
    await client.query(
      'UPDATE bookings SET status = $1, updated_at = current_timestamp WHERE booking_id = $2',
      [BookingStatus.Cancelled, bookingId]
    );

    // Restore trip seats
    await client.query(
      'UPDATE trips SET seats_available = seats_available + $1, updated_at = current_timestamp WHERE trip_id = $2',
      [bookingData.seats_booked, bookingData.trip_id]
    );

    await client.query('COMMIT');

    const updatedBooking = await getBookingById(bookingId);
    return updatedBooking!;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Create rating for completed booking
 * @param bookingId Booking's UUID
 * @param raterId Rater's UUID
 * @param ratingData Rating data
 * @returns Created rating
 */
export const createRating = async (
  bookingId: string,
  raterId: string,
  ratingData: CreateRatingRequest
): Promise<Rating> => {
  // Get booking
  const bookingData = await getBookingById(bookingId);
  if (!bookingData) {
    throw new Error('Booking not found');
  }

  if (bookingData.status !== BookingStatus.Completed) {
    throw new Error('Can only rate completed bookings');
  }

  // Determine ratee (if rider rates, ratee is driver; if driver rates, ratee is rider)
  let rateeId: string;
  if (raterId === bookingData.rider_id) {
    rateeId = bookingData.trip.driver_id;
  } else if (raterId === bookingData.trip.driver_id) {
    rateeId = bookingData.rider_id;
  } else {
    throw new Error('Unauthorized');
  }

  // Check if rating already exists
  const existingRating = await pool.query(
    'SELECT * FROM ratings WHERE booking_id = $1 AND rater_id = $2',
    [bookingId, raterId]
  );

  if (existingRating.rows.length > 0) {
    throw new Error('Rating already exists');
  }

  // Create rating
  const query = `
    INSERT INTO ratings (booking_id, rater_id, ratee_id, score, comment)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING *
  `;

  const result = await pool.query(query, [
    bookingId,
    raterId,
    rateeId,
    ratingData.score,
    ratingData.comment || null,
  ]);

  // Update ratee's average rating
  const avgQuery = `
    UPDATE users
    SET rating = (SELECT COALESCE(AVG(score), 0) FROM ratings WHERE ratee_id = $1),
        updated_at = current_timestamp
    WHERE user_id = $1
  `;
  await pool.query(avgQuery, [rateeId]);

  return result.rows[0];
};

export default {
  createBooking,
  getBookingById,
  listUserBookings,
  confirmBooking,
  cancelBooking,
  createRating,
};
