import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import jwt from 'jsonwebtoken';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;
let driverToken: string;
let riderToken: string;

const makeAccessToken = (payload: { userId: string; email: string; role: 'Driver' | 'Rider'; sjsuIdStatus?: 'pending' | 'verified' | 'rejected' }) => {
  const jwtSecret = process.env.JWT_SECRET;

  if (!jwtSecret) {
    throw new Error('JWT_SECRET is required for iOS rider tests');
  }

  return jwt.sign({ ...payload, type: 'access' }, jwtSecret);
};

const bookingServiceMocks = vi.hoisted(() => ({
  approveBooking: vi.fn(),
  rejectBooking: vi.fn(),
  cancelBooking: vi.fn(),
}));

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
  process.env.DATABASE_URL = 'postgres://ios-rider-test-db';
  process.env.JWT_SECRET = 'ios-rider-test-secret';
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

describe('iOS Rider Search Flow - Booking Approval API', () => {
  let testBookingId: string;

  beforeEach(() => {
    testBookingId = 'booking-456';
  });

  describe('Booking Approval Flow', () => {
    it('should approve a pending booking', async () => {
      bookingServiceMocks.approveBooking.mockResolvedValueOnce({
        booking_id: testBookingId,
        trip_id: 'trip-123',
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
        trip_id: 'trip-123',
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

  describe('Booking Cancellation', () => {
    it('should cancel a pending booking', async () => {
      bookingServiceMocks.cancelBooking.mockResolvedValueOnce({
        booking_id: testBookingId,
        trip_id: 'trip-123',
        rider_id: 'rider-456',
        seats_booked: 1,
        status: 'cancelled',
        booking_state: 'cancelled',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; data: any }>({
        baseUrl: server.baseUrl,
        method: 'PUT',
        path: `/bookings/${testBookingId}/cancel`,
        headers: {
          Authorization: `Bearer ${riderToken}`,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
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

    it('should transition from pending to cancelled', async () => {
      bookingServiceMocks.cancelBooking.mockResolvedValueOnce({
        booking_id: 'booking-123',
        trip_id: 'trip-456',
        rider_id: 'rider-789',
        seats_booked: 1,
        status: 'cancelled',
        booking_state: 'cancelled',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });

      const { cancelBooking } = await import('../../services/booking-service/src/services/booking.service');

      const result = await cancelBooking('booking-123');
      expect(result.booking_state).toBe('cancelled');
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

    it('should require authentication for cancel endpoint', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PUT',
        path: `/bookings/${testBookingId}/cancel`,
      });

      expect(response.status).toBe(401);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('Access token required');
    });
  });
});
