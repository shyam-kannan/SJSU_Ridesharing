import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;

beforeEach(() => {
  vi.resetModules();
  process.env.DATABASE_URL = 'postgres://booking-test-db';
  process.env.JWT_SECRET = 'booking-test-secret';
  process.env.NODE_ENV = 'test';
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
        path: `/api/bookings/${testBookingId}/approve`,
      });

      expect(response.status).toBe(401);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('Access token required');
    });

    it('approves a pending booking successfully', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      // Mock the booking service to return a booking
      const { approveBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(approveBooking).mockResolvedValue({
        booking_id: testBookingId,
        trip_id: testTripId,
        rider_id: testRiderId,
        booking_state: 'approved',
        status: 'confirmed',
        seats_booked: 1,
      });

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/api/bookings/${testBookingId}/approve`,
        headers: {
          'Authorization': 'Bearer valid-token',
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
      expect(response.body.message).toBe('Booking approved successfully');
    });

    it('rejects approving an already approved booking', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const { approveBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(approveBooking).mockRejectedValue(new Error('Booking is already approved'));

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/api/bookings/${testBookingId}/approve`,
        headers: {
          'Authorization': 'Bearer valid-token',
        },
      });

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
    });

    it('rejects approving a rejected booking', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const { approveBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(approveBooking).mockRejectedValue(new Error('Cannot approve a rejected booking'));

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/api/bookings/${testBookingId}/approve`,
        headers: {
          'Authorization': 'Bearer valid-token',
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
        path: `/api/bookings/${testBookingId}/reject`,
      });

      expect(response.status).toBe(401);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('Access token required');
    });

    it('rejects a pending booking successfully', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const { rejectBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(rejectBooking).mockResolvedValue({
        booking_id: testBookingId,
        trip_id: testTripId,
        rider_id: testRiderId,
        booking_state: 'rejected',
        status: 'cancelled',
        seats_booked: 1,
      });

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/api/bookings/${testBookingId}/reject`,
        headers: {
          'Authorization': 'Bearer valid-token',
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
      expect(response.body.message).toBe('Booking rejected successfully');
    });

    it('rejects rejecting an already rejected booking', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const { rejectBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(rejectBooking).mockRejectedValue(new Error('Booking is already rejected'));

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/api/bookings/${testBookingId}/reject`,
        headers: {
          'Authorization': 'Bearer valid-token',
        },
      });

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
    });

    it('rejects rejecting an approved booking', async () => {
      const { default: app } = await import('../../services/booking-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const { rejectBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(rejectBooking).mockRejectedValue(new Error('Cannot reject an approved booking'));

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'PATCH',
        path: `/api/bookings/${testBookingId}/reject`,
        headers: {
          'Authorization': 'Bearer valid-token',
        },
      });

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
    });
  });

  describe('Booking State Transitions', () => {
    it('creates booking with pending state', async () => {
      const { createBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(createBooking).mockResolvedValue({
        booking: {
          booking_id: testBookingId,
          booking_state: 'pending',
          status: 'pending',
        },
        quote: { max_price: 10.0 },
      });

      const result = await createBooking(testRiderId, {
        trip_id: testTripId,
        seats_booked: 1,
      });

      expect(result.booking.booking_state).toBe('pending');
    });

    it('transitions from pending to approved on approve', async () => {
      const { approveBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(approveBooking).mockResolvedValue({
        booking_id: testBookingId,
        booking_state: 'approved',
        status: 'confirmed',
      });

      const result = await approveBooking(testBookingId, testDriverId);

      expect(result.booking_state).toBe('approved');
    });

    it('transitions from pending to rejected on reject', async () => {
      const { rejectBooking } = await import('../../services/booking-service/src/services/booking.service');
      vi.mocked(rejectBooking).mockResolvedValue({
        booking_id: testBookingId,
        booking_state: 'rejected',
        status: 'cancelled',
      });

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
      vi.mocked(getBookingsByTripId).mockResolvedValue([
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
        path: `/api/bookings/trip/${testTripId}`,
        headers: {
          'Authorization': 'Bearer valid-token',
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
        path: `/api/bookings/trip/${testTripId}`,
      });

      expect(response.status).toBe(401);
      expect(response.body.status).toBe('error');
    });
  });
});
