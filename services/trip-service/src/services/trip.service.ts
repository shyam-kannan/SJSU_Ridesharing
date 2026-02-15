import { Pool } from 'pg';
import { config } from '../config';
import { Trip, TripWithDriver, CreateTripRequest, TripStatus, GeoPoint } from '../../../shared/types';
import { geocodeTripLocations } from '../utils/geocoding';

const pool = new Pool({
  connectionString: config.databaseUrl,
});

/**
 * Create a new trip
 * @param driverId Driver's UUID
 * @param tripData Trip creation data
 * @returns Created trip
 */
export const createTrip = async (
  driverId: string,
  tripData: CreateTripRequest
): Promise<Trip> => {
  const { origin, destination, departure_time, seats_available, recurrence } = tripData;

  // Geocode origin and destination
  const { originPoint, destinationPoint } = await geocodeTripLocations(origin, destination);

  const query = `
    INSERT INTO trips (
      driver_id, origin, destination, origin_point, destination_point,
      departure_time, seats_available, recurrence, status
    )
    VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326), ST_SetSRID(ST_MakePoint($6, $7), 4326), $8, $9, $10, $11)
    RETURNING
      trip_id, driver_id, origin, destination,
      ST_X(origin_point::geometry) as origin_lng,
      ST_Y(origin_point::geometry) as origin_lat,
      ST_X(destination_point::geometry) as destination_lng,
      ST_Y(destination_point::geometry) as destination_lat,
      departure_time, seats_available, recurrence, status, created_at, updated_at
  `;

  const values = [
    driverId,
    origin,
    destination,
    originPoint.lng,
    originPoint.lat,
    destinationPoint.lng,
    destinationPoint.lat,
    departure_time,
    seats_available,
    recurrence || null,
    TripStatus.Active,
  ];

  const result = await pool.query(query, values);
  const trip = result.rows[0];

  return {
    ...trip,
    origin_point: { lat: trip.origin_lat, lng: trip.origin_lng },
    destination_point: { lat: trip.destination_lat, lng: trip.destination_lng },
  };
};

/**
 * Get trip by ID
 * @param tripId Trip's UUID
 * @returns Trip if found, null otherwise
 */
export const getTripById = async (tripId: string): Promise<TripWithDriver | null> => {
  const query = `
    SELECT
      t.trip_id, t.driver_id, t.origin, t.destination,
      ST_X(t.origin_point::geometry) as origin_lng,
      ST_Y(t.origin_point::geometry) as origin_lat,
      ST_X(t.destination_point::geometry) as destination_lng,
      ST_Y(t.destination_point::geometry) as destination_lat,
      t.departure_time, t.seats_available, t.recurrence, t.status,
      t.created_at, t.updated_at,
      u.user_id as driver_user_id,
      u.name as driver_name,
      u.email as driver_email,
      u.role as driver_role,
      u.sjsu_id_status as driver_sjsu_id_status,
      u.rating as driver_rating,
      u.vehicle_info as driver_vehicle_info,
      u.seats_available as driver_seats_available,
      u.created_at as driver_created_at,
      u.updated_at as driver_updated_at
    FROM trips t
    JOIN users u ON t.driver_id = u.user_id
    WHERE t.trip_id = $1
  `;

  const result = await pool.query(query, [tripId]);

  if (result.rows.length === 0) {
    return null;
  }

  const row = result.rows[0];

  return {
    trip_id: row.trip_id,
    driver_id: row.driver_id,
    origin: row.origin,
    destination: row.destination,
    origin_point: { lat: row.origin_lat, lng: row.origin_lng },
    destination_point: { lat: row.destination_lat, lng: row.destination_lng },
    departure_time: row.departure_time,
    seats_available: row.seats_available,
    recurrence: row.recurrence,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at,
    driver: {
      user_id: row.driver_user_id,
      name: row.driver_name,
      email: row.driver_email,
      role: row.driver_role,
      sjsu_id_status: row.driver_sjsu_id_status,
      rating: row.driver_rating,
      vehicle_info: row.driver_vehicle_info,
      seats_available: row.driver_seats_available,
      created_at: row.driver_created_at,
      updated_at: row.driver_updated_at,
    },
  };
};

/**
 * Search for trips near a location with geospatial query
 * @param originLat Origin latitude
 * @param originLng Origin longitude
 * @param radiusMeters Search radius in meters
 * @param filters Additional filters
 * @returns Array of matching trips
 */
export const searchTripsNearby = async (
  originLat: number,
  originLng: number,
  radiusMeters: number = config.defaultSearchRadius,
  filters?: {
    minSeats?: number;
    departureAfter?: Date;
    departureBefore?: Date;
    status?: TripStatus;
  }
): Promise<TripWithDriver[]> => {
  let query = `
    SELECT
      t.trip_id, t.driver_id, t.origin, t.destination,
      ST_X(t.origin_point::geometry) as origin_lng,
      ST_Y(t.origin_point::geometry) as origin_lat,
      ST_X(t.destination_point::geometry) as destination_lng,
      ST_Y(t.destination_point::geometry) as destination_lat,
      t.departure_time, t.seats_available, t.recurrence, t.status,
      t.created_at, t.updated_at,
      ST_Distance(
        t.origin_point::geography,
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
      ) as distance_meters,
      u.user_id as driver_user_id,
      u.name as driver_name,
      u.email as driver_email,
      u.role as driver_role,
      u.sjsu_id_status as driver_sjsu_id_status,
      u.rating as driver_rating,
      u.vehicle_info as driver_vehicle_info,
      u.created_at as driver_created_at,
      u.updated_at as driver_updated_at
    FROM trips t
    JOIN users u ON t.driver_id = u.user_id
    WHERE ST_DWithin(
      t.origin_point::geography,
      ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
      $3
    )
  `;

  const values: any[] = [originLng, originLat, radiusMeters];
  let paramIndex = 4;

  // Add filters
  if (filters?.status) {
    query += ` AND t.status = $${paramIndex}`;
    values.push(filters.status);
    paramIndex++;
  } else {
    query += ` AND t.status = $${paramIndex}`;
    values.push(TripStatus.Active);
    paramIndex++;
  }

  if (filters?.minSeats) {
    query += ` AND t.seats_available >= $${paramIndex}`;
    values.push(filters.minSeats);
    paramIndex++;
  }

  if (filters?.departureAfter) {
    query += ` AND t.departure_time >= $${paramIndex}`;
    values.push(filters.departureAfter);
    paramIndex++;
  }

  if (filters?.departureBefore) {
    query += ` AND t.departure_time <= $${paramIndex}`;
    values.push(filters.departureBefore);
    paramIndex++;
  }

  query += ` ORDER BY distance_meters ASC LIMIT 50`;

  const result = await pool.query(query, values);

  return result.rows.map((row) => ({
    trip_id: row.trip_id,
    driver_id: row.driver_id,
    origin: row.origin,
    destination: row.destination,
    origin_point: { lat: row.origin_lat, lng: row.origin_lng },
    destination_point: { lat: row.destination_lat, lng: row.destination_lng },
    departure_time: row.departure_time,
    seats_available: row.seats_available,
    recurrence: row.recurrence,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at,
    driver: {
      user_id: row.driver_user_id,
      name: row.driver_name,
      email: row.driver_email,
      role: row.driver_role,
      sjsu_id_status: row.driver_sjsu_id_status,
      rating: row.driver_rating,
      vehicle_info: row.driver_vehicle_info,
      created_at: row.driver_created_at,
      updated_at: row.driver_updated_at,
    },
  }));
};

/**
 * List trips with filters
 * @param filters Query filters
 * @returns Array of trips
 */
export const listTrips = async (filters?: {
  driverId?: string;
  status?: TripStatus;
  departureAfter?: Date;
  limit?: number;
}): Promise<TripWithDriver[]> => {
  let query = `
    SELECT
      t.trip_id, t.driver_id, t.origin, t.destination,
      ST_X(t.origin_point::geometry) as origin_lng,
      ST_Y(t.origin_point::geometry) as origin_lat,
      ST_X(t.destination_point::geometry) as destination_lng,
      ST_Y(t.destination_point::geometry) as destination_lat,
      t.departure_time, t.seats_available, t.recurrence, t.status,
      t.created_at, t.updated_at,
      u.user_id as driver_user_id,
      u.name as driver_name,
      u.email as driver_email,
      u.role as driver_role,
      u.sjsu_id_status as driver_sjsu_id_status,
      u.rating as driver_rating,
      u.vehicle_info as driver_vehicle_info,
      u.created_at as driver_created_at,
      u.updated_at as driver_updated_at
    FROM trips t
    JOIN users u ON t.driver_id = u.user_id
    WHERE 1=1
  `;

  const values: any[] = [];
  let paramIndex = 1;

  if (filters?.driverId) {
    query += ` AND t.driver_id = $${paramIndex}`;
    values.push(filters.driverId);
    paramIndex++;
  }

  if (filters?.status) {
    query += ` AND t.status = $${paramIndex}`;
    values.push(filters.status);
    paramIndex++;
  }

  if (filters?.departureAfter) {
    query += ` AND t.departure_time >= $${paramIndex}`;
    values.push(filters.departureAfter);
    paramIndex++;
  }

  query += ` ORDER BY t.departure_time ASC`;

  if (filters?.limit) {
    query += ` LIMIT $${paramIndex}`;
    values.push(filters.limit);
  } else {
    query += ` LIMIT 100`;
  }

  const result = await pool.query(query, values);

  return result.rows.map((row) => ({
    trip_id: row.trip_id,
    driver_id: row.driver_id,
    origin: row.origin,
    destination: row.destination,
    origin_point: { lat: row.origin_lat, lng: row.origin_lng },
    destination_point: { lat: row.destination_lat, lng: row.destination_lng },
    departure_time: row.departure_time,
    seats_available: row.seats_available,
    recurrence: row.recurrence,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at,
    driver: {
      user_id: row.driver_user_id,
      name: row.driver_name,
      email: row.driver_email,
      role: row.driver_role,
      sjsu_id_status: row.driver_sjsu_id_status,
      rating: row.driver_rating,
      vehicle_info: row.driver_vehicle_info,
      created_at: row.driver_created_at,
      updated_at: row.driver_updated_at,
    },
  }));
};

/**
 * Update trip
 * @param tripId Trip's UUID
 * @param driverId Driver's UUID (for authorization)
 * @param updates Trip updates
 * @returns Updated trip
 */
export const updateTrip = async (
  tripId: string,
  driverId: string,
  updates: Partial<CreateTripRequest>
): Promise<Trip> => {
  // Verify trip belongs to driver
  const trip = await getTripById(tripId);
  if (!trip) {
    throw new Error('Trip not found');
  }
  if (trip.driver_id !== driverId) {
    throw new Error('Unauthorized');
  }

  const fields: string[] = [];
  const values: any[] = [];
  let paramIndex = 1;

  if (updates.departure_time) {
    fields.push(`departure_time = $${paramIndex}`);
    values.push(updates.departure_time);
    paramIndex++;
  }

  if (updates.seats_available !== undefined) {
    fields.push(`seats_available = $${paramIndex}`);
    values.push(updates.seats_available);
    paramIndex++;
  }

  if (updates.recurrence !== undefined) {
    fields.push(`recurrence = $${paramIndex}`);
    values.push(updates.recurrence);
    paramIndex++;
  }

  if (fields.length === 0) {
    throw new Error('No fields to update');
  }

  fields.push(`updated_at = current_timestamp`);
  values.push(tripId);

  const query = `
    UPDATE trips
    SET ${fields.join(', ')}
    WHERE trip_id = $${paramIndex}
    RETURNING
      trip_id, driver_id, origin, destination,
      ST_X(origin_point::geometry) as origin_lng,
      ST_Y(origin_point::geometry) as origin_lat,
      ST_X(destination_point::geometry) as destination_lng,
      ST_Y(destination_point::geometry) as destination_lat,
      departure_time, seats_available, recurrence, status, created_at, updated_at
  `;

  const result = await pool.query(query, values);
  const updatedTrip = result.rows[0];

  return {
    ...updatedTrip,
    origin_point: { lat: updatedTrip.origin_lat, lng: updatedTrip.origin_lng },
    destination_point: { lat: updatedTrip.destination_lat, lng: updatedTrip.destination_lng },
  };
};

/**
 * Cancel trip (set status to cancelled)
 * @param tripId Trip's UUID
 * @param driverId Driver's UUID (for authorization)
 * @returns Updated trip
 */
export const cancelTrip = async (tripId: string, driverId: string): Promise<Trip> => {
  // Verify trip belongs to driver
  const trip = await getTripById(tripId);
  if (!trip) {
    throw new Error('Trip not found');
  }
  if (trip.driver_id !== driverId) {
    throw new Error('Unauthorized');
  }

  const query = `
    UPDATE trips
    SET status = $1, updated_at = current_timestamp
    WHERE trip_id = $2
    RETURNING
      trip_id, driver_id, origin, destination,
      ST_X(origin_point::geometry) as origin_lng,
      ST_Y(origin_point::geometry) as origin_lat,
      ST_X(destination_point::geometry) as destination_lng,
      ST_Y(destination_point::geometry) as destination_lat,
      departure_time, seats_available, recurrence, status, created_at, updated_at
  `;

  const result = await pool.query(query, [TripStatus.Cancelled, tripId]);
  const cancelledTrip = result.rows[0];

  return {
    ...cancelledTrip,
    origin_point: { lat: cancelledTrip.origin_lat, lng: cancelledTrip.origin_lng },
    destination_point: { lat: cancelledTrip.destination_lat, lng: cancelledTrip.destination_lng },
  };
};

export default {
  createTrip,
  getTripById,
  searchTripsNearby,
  listTrips,
  updateTrip,
  cancelTrip,
};
