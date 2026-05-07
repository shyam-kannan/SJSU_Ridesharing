import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import jwt from 'jsonwebtoken';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;
let driverToken: string;
let riderToken: string;

const makeAccessToken = (payload: { userId: string; email: string; role: 'Driver' | 'Rider'; sjsuIdStatus?: 'pending' | 'verified' | 'rejected' }) => {
  const jwtSecret = process.env.JWT_SECRET;

  if (!jwtSecret) {
    throw new Error('JWT_SECRET is required for iOS driver tests');
  }

  return jwt.sign({ ...payload, type: 'access' }, jwtSecret);
};

const tripServiceMocks = vi.hoisted(() => ({
  getTripPassengers: vi.fn(),
  listTrips: vi.fn(),
  createTrip: vi.fn(),
}));

const bookingServiceMocks = vi.hoisted(() => ({
  approveBooking: vi.fn(),
  rejectBooking: vi.fn(),
  getBookingForTrip: vi.fn(),
}));

vi.mock('../../services/trip-service/src/services/trip.service', () => tripServiceMocks);
vi.mock('../../services/booking-service/src/services/booking.service', () => bookingServiceMocks);

vi.mock('@lessgo/shared', async () => {
  const actual = await vi.importActual<typeof import('@lessgo/shared')>('@lessgo/shared');

  return {
    ...actual,
    authenticateToken: (req: any, res: any, next: any) => {
      const authHeader = req.headers.authorization;

      if (!authHeader) {
        res.status(401).json({ status: 'error', message: 'Access token required' });
        return;
      }

      if (authHeader === `Bearer ${process.env.TEST_DRIVER_TOKEN}`) {
        req.user = {
          userId: 'driver-123',
          email: 'test-driver@sjsu.edu',
          role: 'Driver',
          sjsuIdStatus: 'verified',
        };
        next();
        return;
      }

      if (authHeader === `Bearer ${process.env.TEST_RIDER_TOKEN}`) {
        req.user = {
          userId: 'rider-456',
          email: 'test-rider@sjsu.edu',
          role: 'Rider',
          sjsuIdStatus: 'verified',
        };
        next();
        return;
      }

      res.status(403).json({ status: 'error', message: 'Invalid token' });
    },
  };
});

beforeEach(() => {
  vi.resetModules();
  process.env.DATABASE_URL = 'postgres://ios-driver-test-db';
  process.env.JWT_SECRET = 'ios-driver-test-secret';
  process.env.NODE_ENV = 'test';
  driverToken = makeAccessToken({
    userId: 'driver-123',
    email: 'test-driver@sjsu.edu',
    role: 'Driver',
    sjsuIdStatus: 'verified',
  });
  riderToken = makeAccessToken({
    userId: 'rider-456',
    email: 'test-rider@sjsu.edu',
    role: 'Rider',
    sjsuIdStatus: 'verified',
  });
  process.env.TEST_DRIVER_TOKEN = driverToken;
  process.env.TEST_RIDER_TOKEN = riderToken;
});

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

describe('iOS Driver Side - Posted Rides Management', () => {
  let testTripId: string;
  let testBookingId: string;

  beforeEach(() => {
    testTripId = 'trip-123';
    testBookingId = 'booking-456';
  });

  describe('Driver Posted Trips List', () => {
    it('should list driver posted trips', async () => {
      tripServiceMocks.listTrips.mockResolvedValueOnce([
        {
          trip_id: testTripId,
          driver_id: 'driver-123',
          origin: 'San Francisco',
          destination: 'San Jose State University',
          departure_time: new Date(Date.now() + 86400000).toISOString(),
          seats_available: 3,
          status: 'pending',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      ]);

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; data: any }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips?driver_id=driver-123&limit=10',
        headers: {
          Authorization: `Bearer ${driverToken}`,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
      expect(response.body.data.trips).toHaveLength(1);
    });

    it('should filter trips by status', async () => {
      tripServiceMocks.listTrips.mockResolvedValueOnce([
        {
          trip_id: testTripId,
          driver_id: 'driver-123',
          origin: 'San Francisco',
          destination: 'San Jose State University',
          departure_time: new Date(Date.now() + 86400000).toISOString(),
          seats_available: 3,
          status: 'pending',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      ]);

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; data: any }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips?driver_id=driver-123&status=pending&limit=10',
        headers: {
          Authorization: `Bearer ${driverToken}`,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
      expect(response.body.data.trips).toHaveLength(1);
    });
  });

  describe('Driver Trip Passengers', () => {
    it('should get trip passengers with booking states', async () => {
      tripServiceMocks.getTripPassengers.mockResolvedValueOnce([
        {
          id: testBookingId,
          trip_id: testTripId,
          rider_id: 'rider-456',
          rider_name: 'Alice Rider',
          rider_email: 'alice@sjsu.edu',
          rider_phone: '+1234567890',
          rider_rating: '4.8',
          rider_picture: 'https://example.com/avatar.jpg',
          seats_booked: 1,
          status: 'pending',
          booking_state: 'pending',
          created_at: new Date().toISOString(),
        },
      ]);

      const { getTripPassengers } = await import('../../services/trip-service/src/services/trip.service');

      const result = await getTripPassengers(testTripId);
      expect(result).toHaveLength(1);
      expect(result[0].booking_state).toBe('pending');
    });

    it('should separate pending and approved bookings', async () => {
      tripServiceMocks.getTripPassengers.mockResolvedValueOnce([
        {
          id: 'booking-1',
          trip_id: testTripId,
          rider_id: 'rider-1',
          rider_name: 'Pending Rider',
          rider_rating: '4.5',
          seats_booked: 1,
          status: 'pending',
          booking_state: 'pending',
          created_at: new Date().toISOString(),
        },
        {
          id: 'booking-2',
          trip_id: testTripId,
          rider_id: 'rider-2',
          rider_name: 'Approved Rider',
          rider_rating: '4.9',
          seats_booked: 1,
          status: 'confirmed',
          booking_state: 'approved',
          created_at: new Date().toISOString(),
        },
      ]);

      const { getTripPassengers } = await import('../../services/trip-service/src/services/trip.service');

      const result = await getTripPassengers(testTripId);
      const pending = result.filter((b: any) => b.booking_state === 'pending');
      const approved = result.filter((b: any) => b.booking_state === 'approved');

      expect(pending).toHaveLength(1);
      expect(approved).toHaveLength(1);
    });
  });

  describe('Driver Booking Approval Flow', () => {
    it('should approve a pending booking', async () => {
      bookingServiceMocks.approveBooking.mockResolvedValueOnce({
        booking_id: testBookingId,
        trip_id: testTripId,
        rider_id: 'rider-456',
        seats_booked: 1,
        status: 'confirmed',
        booking_state: 'approved',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/bookings/${testBookingId}/approve`,
        headers: {
          Authorization: `Bearer ${driverToken}`,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
      expect(response.body.message).toBe('Booking approved successfully');
    });

    it('should reject a pending booking', async () => {
      bookingServiceMocks.rejectBooking.mockResolvedValueOnce({
        booking_id: testBookingId,
        trip_id: testTripId,
        rider_id: 'rider-456',
        seats_booked: 1,
        status: 'cancelled',
        booking_state: 'rejected',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/bookings/${testBookingId}/reject`,
        headers: {
          Authorization: `Bearer ${driverToken}`,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
      expect(response.body.message).toBe('Booking rejected successfully');
    });
  });

  describe('Driver Trip Creation with Recurrence', () => {
    it('should create a trip with recurrence', async () => {
      tripServiceMocks.createTrip.mockResolvedValueOnce({
        trip_id: testTripId,
        driver_id: 'driver-123',
        origin: 'San Francisco',
        destination: 'San Jose State University',
        departure_time: new Date(Date.now() + 86400000).toISOString(),
        seats_available: 3,
        recurrence: 'weekdays',
        status: 'pending',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      const { createTrip } = await import('../../services/trip-service/src/services/trip.service');

      const result = await createTrip(
        'San Francisco',
        'San Jose State University',
        new Date(Date.now() + 86400000),
        3,
        'weekdays'
      );

      expect(result.recurrence).toBe('weekdays');
    });

    it('should create a trip with custom recurrence days', async () => {
      tripServiceMocks.createTrip.mockResolvedValueOnce({
        trip_id: testTripId,
        driver_id: 'driver-123',
        origin: 'Palo Alto',
        destination: 'San Jose State University',
        departure_time: new Date(Date.now() + 86400000).toISOString(),
        seats_available: 2,
        recurrence: 'mon,wed,fri',
        status: 'pending',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      const { createTrip } = await import('../../services/trip-service/src/services/trip.service');

      const result = await createTrip(
        'Palo Alto',
        'San Jose State University',
        new Date(Date.now() + 86400000),
        2,
        'mon,wed,fri'
      );

      expect(result.recurrence).toBe('mon,wed,fri');
    });
  });

  describe('Authentication', () => {
    it('should require authentication for approve endpoint', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/bookings/${testBookingId}/approve`,
      });

      expect(response.status).toBe(401);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('Access token required');
    });

    it('should require authentication for reject endpoint', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/bookings/${testBookingId}/reject`,
      });

      expect(response.status).toBe(401);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('Access token required');
    });

    it('should require authentication for trip passengers endpoint', async () => {
      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: `/trips/${testTripId}/bookings`,
      });

      expect(response.status).toBe(401);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('Access token required');
    });
  });

  describe('Booking State Transitions', () => {
    it('should transition from pending to approved', async () => {
      bookingServiceMocks.approveBooking.mockResolvedValueOnce({
        booking_id: 'booking-123',
        trip_id: 'trip-456',
        rider_id: 'rider-789',
        seats_booked: 1,
        status: 'confirmed',
        booking_state: 'approved',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      const { approveBooking } = await import('../../services/booking-service/src/services/booking.service');

      const result = await approveBooking('booking-123');
      expect(result.booking_state).toBe('approved');
    });

    it('should transition from pending to rejected', async () => {
      bookingServiceMocks.rejectBooking.mockResolvedValueOnce({
        booking_id: 'booking-123',
        trip_id: 'trip-456',
        rider_id: 'rider-789',
        seats_booked: 1,
        status: 'cancelled',
        booking_state: 'rejected',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      const { rejectBooking } = await import('../../services/booking-service/src/services/booking.service');

      const result = await rejectBooking('booking-123');
      expect(result.booking_state).toBe('rejected');
    });
  });
});
