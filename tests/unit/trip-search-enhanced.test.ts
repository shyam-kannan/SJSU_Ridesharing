import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import axios from 'axios';
import jwt from 'jsonwebtoken';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;
let driverToken: string;
let riderToken: string;

const makeAccessToken = (payload: { userId: string; email: string; role: 'Driver' | 'Rider'; sjsuIdStatus?: 'pending' | 'verified' | 'rejected' }) => {
  const jwtSecret = process.env.JWT_SECRET;

  if (!jwtSecret) {
    throw new Error('JWT_SECRET is required for trip tests');
  }

  return jwt.sign({ ...payload, type: 'access' }, jwtSecret);
};

const tripServiceMocks = vi.hoisted(() => ({
  searchTripsNearby: vi.fn(),
  createTrip: vi.fn(),
  isLocationNearSJSU: vi.fn(),
}));

vi.mock('../../services/trip-service/src/services/trip.service', () => tripServiceMocks);

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

      if (authHeader === `Bearer ${process.env.TEST_RIDER_TOKEN}`) {
        req.user = {
          userId: 'rider-456',
          email: 'sim-rider@sjsu.edu',
          role: 'Rider',
          sjsuIdStatus: 'verified',
        };
        next();
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
    requireDriver: (req: any, res: any, next: any) => {
      if (!req.user) {
        res.status(401).json({ status: 'error', message: 'Authentication required' });
        return;
      }

      if (req.user.role !== 'Driver') {
        res.status(403).json({ status: 'error', message: 'Only drivers can create trips' });
        return;
      }

      next();
    },
    requireVerifiedStudent: (req: any, res: any, next: any) => {
      if (!req.user) {
        res.status(401).json({ status: 'error', message: 'Authentication required' });
        return;
      }

      next();
    },
  };
});

beforeEach(() => {
  vi.resetModules();
  process.env.DATABASE_URL = 'postgres://trip-test-db';
  process.env.GOOGLE_MAPS_API_KEY = 'trip-test-key';
  process.env.JWT_SECRET = 'trip-test-secret';
  process.env.NODE_ENV = 'test';
  driverToken = makeAccessToken({
    userId: 'driver-123',
    email: 'sim-driver@sjsu.edu',
    role: 'Driver',
    sjsuIdStatus: 'verified',
  });
  riderToken = makeAccessToken({
    userId: 'rider-456',
    email: 'sim-rider@sjsu.edu',
    role: 'Rider',
    sjsuIdStatus: 'verified',
  });
  process.env.TEST_DRIVER_TOKEN = driverToken;
  process.env.TEST_RIDER_TOKEN = riderToken;

  vi.mocked(axios.get).mockResolvedValue({
    data: {
      data: {
        vehicle_info: 'Honda Civic',
        seats_available: 4,
        license_plate: 'ABC123',
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

describe('Enhanced Trip Search Endpoint', () => {
  describe('GET /api/trips/search', () => {
    it('requires origin_lat and origin_lng parameters', async () => {
      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
      });

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('origin_lat and origin_lng are required');
    });

    it('validates coordinates are numbers', async () => {
      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 'invalid',
          origin_lng: -122.8811,
        },
      });

      expect(response.status).toBe(400);
      expect(response.body.status).toBe('error');
      expect(response.body.message).toBe('Invalid coordinates');
    });

    it('returns trips with pagination', async () => {
      tripServiceMocks.searchTripsNearby.mockResolvedValueOnce([
        {
          trip_id: 'trip-1',
          driver_id: 'driver-1',
          origin: 'San Francisco',
          destination: 'SJSU',
          departure_time: new Date('2026-05-04T09:00:00Z'),
          seats_available: 3,
          featured: false,
          max_riders: 3,
        },
        {
          trip_id: 'trip-2',
          driver_id: 'driver-2',
          origin: 'Palo Alto',
          destination: 'SJSU',
          departure_time: new Date('2026-05-04T09:30:00Z'),
          seats_available: 2,
          featured: true,
          max_riders: 4,
        },
      ]);

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{
        status: string;
        data: { trips: any[]; total: number; has_more: boolean };
      }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 37.3352,
          origin_lng: -122.8811,
          limit: 10,
          offset: 0,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe('success');
      expect(response.body.data.trips).toHaveLength(2);
      expect(response.body.data.total).toBe(2);
      expect(response.body.data.has_more).toBe(false);
    });

    it('supports pagination with limit and offset', async () => {
      tripServiceMocks.searchTripsNearby.mockResolvedValueOnce([
        { trip_id: 'trip-1', seats_available: 3 },
        { trip_id: 'trip-2', seats_available: 2 },
      ]);

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{
        status: string;
        data: { trips: any[]; total: number; has_more: boolean };
      }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 37.3352,
          origin_lng: -122.8811,
          limit: 10,
          offset: 0,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.data.trips).toHaveLength(2);
      expect(response.body.data.has_more).toBe(false);
    });

    it('indicates when more results are available', async () => {
      tripServiceMocks.searchTripsNearby.mockResolvedValueOnce(
        Array.from({ length: 10 }, (_, i) => ({
          trip_id: `trip-${i}`,
          seats_available: 3,
        }))
      );

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{
        status: string;
        data: { trips: any[]; total: number; has_more: boolean };
      }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 37.3352,
          origin_lng: -122.8811,
          limit: 10,
          offset: 0,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.data.trips).toHaveLength(10);
      expect(response.body.data.has_more).toBe(true);
    });

    it('supports destination coordinates for from_sjsu direction', async () => {
      tripServiceMocks.searchTripsNearby.mockResolvedValueOnce([
        {
          trip_id: 'trip-1',
          origin: 'SJSU',
          destination: 'San Francisco',
          departure_time: new Date('2026-05-04T17:00:00Z'),
          seats_available: 3,
        },
      ]);

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{
        status: string;
        data: { search_params: any };
      }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 37.3352,
          origin_lng: -122.8811,
          destination_lat: 37.7749,
          destination_lng: -122.4194,
          limit: 10,
          offset: 0,
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.data.search_params.destination).toBeDefined();
      expect(response.body.data.search_params.destination.lat).toBe(37.7749);
      expect(response.body.data.search_params.destination.lng).toBe(-122.4194);
    });

    it('supports departure time filters', async () => {
      tripServiceMocks.searchTripsNearby.mockResolvedValueOnce([
        {
          trip_id: 'trip-1',
          departure_time: new Date('2026-05-04T09:00:00Z'),
          seats_available: 3,
        },
      ]);

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 37.3352,
          origin_lng: -122.8811,
          departure_after: '2026-05-04T08:00:00Z',
          departure_before: '2026-05-04T10:00:00Z',
          limit: 10,
          offset: 0,
        },
      });

      expect(response.status).toBe(200);
    });

    it('supports min_seats filter', async () => {
      tripServiceMocks.searchTripsNearby.mockResolvedValueOnce([
        {
          trip_id: 'trip-1',
          seats_available: 3,
        },
      ]);

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 37.3352,
          origin_lng: -122.8811,
          min_seats: '2',
          limit: 10,
          offset: '0',
        },
      });

      expect(response.status).toBe(200);
    });

    it('limits max results to 50', async () => {
      tripServiceMocks.searchTripsNearby.mockResolvedValueOnce(
        Array.from({ length: 50 }, (_, i) => ({
          trip_id: `trip-${i}`,
          seats_available: 3,
        }))
      );

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{ status: string }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 37.3352,
          origin_lng: -122.8811,
          limit: 100, // Should be capped at 50
          offset: '0',
        },
      });

      expect(response.status).toBe(200);
      // The service should cap at 50
    });

    it('returns empty array when no trips found', async () => {
      tripServiceMocks.searchTripsNearby.mockResolvedValueOnce([]);

      const { default: app } = await import('../../services/trip-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const response = await requestJson<{
        status: string;
        data: { trips: any[]; total: number; has_more: boolean };
      }>({
        baseUrl: server.baseUrl,
        method: 'GET',
        path: '/trips/search',
        query: {
          origin_lat: 37.3352,
          origin_lng: -122.8811,
          limit: 10,
          offset: '0',
        },
      });

      expect(response.status).toBe(200);
      expect(response.body.data.trips).toHaveLength(0);
      expect(response.body.data.total).toBe(0);
      expect(response.body.data.has_more).toBe(false);
    });
  });

  describe('Trip Creation with SJSU Validation', () => {
    describe('POST /api/trips', () => {
      it('requires authentication', async () => {
        const { default: app } = await import('../../services/trip-service/src/app');
        const server = await startTestServer(app);
        closeServer = server.close;

        const response = await requestJson<{ status: string; message: string }>({
          baseUrl: server.baseUrl,
          method: 'POST',
          path: '/trips',
          body: {
            origin: 'San Francisco',
            destination: 'SJSU',
            departure_time: new Date(Date.now() + 3_600_000).toISOString(),
            seats_available: 3,
          },
        });

        expect(response.status).toBe(401);
        expect(response.body.status).toBe('error');
        expect(response.body.message).toBe('Access token required');
      });

      it('requires driver role', async () => {
        const { default: app } = await import('../../services/trip-service/src/app');
        const server = await startTestServer(app);
        closeServer = server.close;

        const response = await requestJson<{ status: string; message: string }>({
          baseUrl: server.baseUrl,
          method: 'POST',
          path: '/trips',
          headers: {
            Authorization: `Bearer ${riderToken}`,
          },
          body: {
            origin: 'San Francisco',
            destination: 'SJSU',
            departure_time: new Date(Date.now() + 3_600_000).toISOString(),
            seats_available: 3,
          },
        });

        expect(response.status).toBe(403);
        expect(response.body.status).toBe('error');
        expect(response.body.message).toBe('Only drivers can create trips');
      });

      it('accepts trip with SJSU as origin', async () => {
        tripServiceMocks.createTrip.mockResolvedValueOnce({
          trip_id: 'trip-1',
          origin: 'San Jose State University',
          destination: 'Downtown San Jose',
          featured: false,
          max_riders: 3,
        });
        tripServiceMocks.isLocationNearSJSU.mockResolvedValueOnce(true);

        const { default: app } = await import('../../services/trip-service/src/app');
        const server = await startTestServer(app);
        closeServer = server.close;

        const response = await requestJson<{ status: string }>({
          baseUrl: server.baseUrl,
          method: 'POST',
          path: '/trips',
          headers: {
            Authorization: `Bearer ${driverToken}`,
          },
          body: {
            origin: 'San Jose State University',
            destination: 'Downtown San Jose',
            departure_time: new Date(Date.now() + 3_600_000).toISOString(),
            seats_available: 3,
          },
        });

        expect(response.status).toBe(201);
        expect(response.body.status).toBe('success');
      });

      it('accepts trip with SJSU as destination', async () => {
        tripServiceMocks.createTrip.mockResolvedValueOnce({
          trip_id: 'trip-1',
          origin: 'Downtown San Jose',
          destination: 'San Jose State University',
          featured: false,
          max_riders: 3,
        });
        tripServiceMocks.isLocationNearSJSU.mockResolvedValueOnce(true);

        const { default: app } = await import('../../services/trip-service/src/app');
        const server = await startTestServer(app);
        closeServer = server.close;

        const response = await requestJson<{ status: string }>({
          baseUrl: server.baseUrl,
          method: 'POST',
          path: '/trips',
          headers: {
            Authorization: `Bearer ${driverToken}`,
          },
          body: {
            origin: 'Downtown San Jose',
            destination: 'San Jose State University',
            departure_time: new Date(Date.now() + 3_600_000).toISOString(),
            seats_available: 3,
          },
        });

        expect(response.status).toBe(201);
        expect(response.body.status).toBe('success');
      });

      it('rejects trip with neither origin nor destination near SJSU', async () => {
        tripServiceMocks.isLocationNearSJSU.mockResolvedValueOnce(false);

        const { default: app } = await import('../../services/trip-service/src/app');
        const server = await startTestServer(app);
        closeServer = server.close;

        const response = await requestJson<{ status: string; message: string }>({
          baseUrl: server.baseUrl,
          method: 'POST',
          path: '/trips',
          headers: {
            Authorization: `Bearer ${driverToken}`,
          },
          body: {
            origin: 'Downtown San Francisco',
            destination: 'Oakland',
            departure_time: new Date(Date.now() + 3_600_000).toISOString(),
            seats_available: 3,
          },
        });

        expect(response.status).toBe(400);
        expect(response.body.status).toBe('error');
        expect(response.body.message).toContain('All LessGo trips must connect to SJSU');
      });

      it('rejects trip creation when driver profile is incomplete', async () => {
        vi.mocked(axios.get).mockResolvedValueOnce({
          data: {
            data: {
              vehicle_info: null,
              seats_available: null,
              license_plate: null,
            },
          },
        } as any);

        const { default: app } = await import('../../services/trip-service/src/app');
        const server = await startTestServer(app);
        closeServer = server.close;

        const response = await requestJson<{ status: string; message: string }>({
          baseUrl: server.baseUrl,
          method: 'POST',
          path: '/trips',
          headers: {
            Authorization: `Bearer ${driverToken}`,
          },
          body: {
            origin: 'San Francisco',
            destination: 'SJSU',
            departure_time: new Date(Date.now() + 3_600_000).toISOString(),
            seats_available: 3,
          },
        });

        expect(response.status).toBe(400);
        expect(response.body.status).toBe('error');
        expect(response.body.message).toBe('Please complete your driver profile before creating trips');
      });
    });
  });
});
