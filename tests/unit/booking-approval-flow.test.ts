import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import axios from 'axios';
import jwt from 'jsonwebtoken';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;
let driverToken: string;

const makeAccessToken = (payload: { userId: string; email: string; role: 'Driver' | 'Rider'; sjsuIdStatus?: 'pending' | 'verified' | 'rejected' }) => {
  const jwtSecret = process.env.JWT_SECRET;

  if (!jwtSecret) {
    throw new Error('JWT_SECRET is required for booking tests');
  }

  return jwt.sign({ ...payload, type: 'access' }, jwtSecret);
};

const bookingServiceMocks = vi.hoisted(() => ({
  createBooking: vi.fn(),
  approveBooking: vi.fn(),
  rejectBooking: vi.fn(),
  getBookingsByTripId: vi.fn(),
}));

vi.mock('../../services/booking-service/src/services/booking.service', () => bookingServiceMocks);

vi.mock('axios', () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
  },
  get: vi.fn(),
  post: vi.fn(),
  isAxiosError: vi.fn((error) => Boolean((error as any)?.isAxiosError)),
}));

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
          email: 'sim-driver@sjsu.edu',
          role: 'Driver',
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
  process.env.DATABASE_URL = 'postgres://booking-test-db';
  process.env.JWT_SECRET = 'booking-test-secret';
  process.env.NODE_ENV = 'test';
  driverToken = makeAccessToken({
    userId: 'driver-123',
    email: 'sim-driver@sjsu.edu',
    role: 'Driver',
    sjsuIdStatus: 'verified',
  });
  process.env.TEST_DRIVER_TOKEN = driverToken;

  vi.mocked(axios.get).mockResolvedValue({
    data: {
      data: {
        driver_id: 'driver-123',
      },
    },
  } as any);
});

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

describe('Booking Approval Flow', () => {
  let testTripId: string;
  let testDriverId: string;
  let testRiderId: string;
  let testBookingId: string;

  beforeEach(async () => {
    const { default: app } = await import('../../services/booking-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    // Setup test data
    testDriverId = 'driver-123';
    testRiderId = 'rider-456';
    testTripId = 'trip-789';
    testBookingId = 'booking-101';
  });

  describe('PATCH /api/bookings/:id/approve', () => {
    it('requires authentication', async () => {
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

    it('approves a pending booking successfully', async () => {
      bookingServiceMocks.approveBooking.mockResolvedValueOnce({
        booking_id: testBookingId,
        trip_id: testTripId,
        rider_id: testRiderId,
        booking_state: 'approved',
        status: 'confirmed',
        seats_booked: 1,
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

    it('rejects approving an already approved booking', async () => {
      bookingServiceMocks.approveBooking.mockRejectedValueOnce(new Error('Booking is already approved'));

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

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
    });

    it('rejects approving a rejected booking', async () => {
      bookingServiceMocks.approveBooking.mockRejectedValueOnce(new Error('Cannot approve a rejected booking'));

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

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
    });
  });

  describe('PATCH /api/bookings/:id/reject', () => {
    it('requires authentication', async () => {
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

    it('rejects a pending booking successfully', async () => {
      bookingServiceMocks.rejectBooking.mockResolvedValueOnce({
        booking_id: testBookingId,
        trip_id: testTripId,
        rider_id: testRiderId,
        booking_state: 'rejected',
        status: 'cancelled',
        seats_booked: 1,
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

    it('rejects rejecting an already rejected booking', async () => {
      bookingServiceMocks.rejectBooking.mockRejectedValueOnce(new Error('Booking is already rejected'));

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

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
    });

    it('rejects rejecting an approved booking', async () => {
      bookingServiceMocks.rejectBooking.mockRejectedValueOnce(new Error('Cannot reject an approved booking'));

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

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
    });
  });

  describe('Booking State Transitions', () => {
    it('creates booking with pending state', async () => {
      bookingServiceMocks.createBooking.mockResolvedValueOnce({
        booking: {
          booking_id: testBookingId,
          booking_state: 'pending',
          status: 'pending',
        },
        quote: { max_price: 10.0 },
      });

      const { createBooking } = await import('../../services/booking-service/src/services/booking.service');

      const result = await createBooking(testRiderId, {
        trip_id: testTripId,
        seats_booked: 1,
      });

      expect(result.booking.booking_state).toBe('pending');
    });

    it('transitions from pending to approved on approve', async () => {
      bookingServiceMocks.approveBooking.mockResolvedValueOnce({
        booking_id: testBookingId,
        booking_state: 'approved',
        status: 'confirmed',
      });

      const { approveBooking } = await import('../../services/booking-service/src/services/booking.service');

      const result = await approveBooking(testBookingId, testDriverId);

      expect(result.booking_state).toBe('approved');
    });

    it('transitions from pending to rejected on reject', async () => {
      bookingServiceMocks.rejectBooking.mockResolvedValueOnce({
        booking_id: testBookingId,
        booking_state: 'rejected',
        status: 'cancelled',
      });

      const { rejectBooking } = await import('../../services/booking-service/src/services/booking.service');

      const result = await rejectBooking(testBookingId, testDriverId);

      expect(result.booking_state).toBe('rejected');
    });
  });

  describe('GET /api/bookings/trip/:tripId', () => {
    it('returns bookings for a trip', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const { getBookingsByTripId } = await import('../../services/booking-service/src/services/booking.service');
      bookingServiceMocks.getBookingsByTripId.mockResolvedValueOnce([
        {
          id: testBookingId,
          trip_id: testTripId,
          rider_id: testRiderId,
          booking_state: 'pending',
          rider_name: 'Test Rider',
          rider_rating: 4.5,
        },
      ]);

      const response = await requestJson<{ status: string; data: any[] }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: `/bookings/trip/${testTripId}`,
        headers: {
          Authorization: `Bearer ${driverToken}`,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
      expect(response.body.data).toHaveLength(1);
      expect(response.body.data[0].booking_state).toBe('pending');
    });

    it('requires authentication', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: `/bookings/trip/${testTripId}`,
      });

      expect(response.status).toBe(401);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('Access token required');
    });
  });
});
