import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';

const axiosGet  = vi.fn();
const axiosPost = vi.fn();

vi.mock('axios', () => ({
  default: {
    get:  axiosGet,
    post: axiosPost,
  },
}));

let closeServer: (() => Promise<void>) | null = null;

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

beforeEach(() => {
  axiosGet.mockReset();
  axiosPost.mockReset();
});

describe('services/cost-calculation-service > GET /cost/settle/:trip_id', () => {
  it('returns 404 when the trip service says the trip does not exist', async () => {
    axiosGet.mockRejectedValueOnce({ response: { status: 404 } });

    const { default: app } = await import('../../services/cost-calculation-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/cost/settle/nonexistent-trip',
    });

    expect(res.status).toBe(404);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toContain('nonexistent-trip');
  });

  it('returns a complete settlement when all services respond', async () => {
    const tripData = {
      trip_id:     'trip-123',
      driver_id:   'driver-001',
      origin:      'SJSU',
      destination: 'Caltrain',
      origin_point:      { lat: 37.3352, lng: -121.8811 },
      destination_point: { lat: 37.3305, lng: -121.8869 },
    };

    const bookingsData = [
      { rider_id: 'rider-a', rider_name: 'Alice', seats_booked: 1, status: 'confirmed' },
      { rider_id: 'rider-b', rider_name: 'Bob',   seats_booked: 1, status: 'confirmed' },
    ];

    // GET calls: 1st = trip, 2nd = driver MPG, 3rd = bookings
    axiosGet
      .mockResolvedValueOnce({ data: { data: tripData } })          // trip
      .mockResolvedValueOnce({ data: { data: { mpg: 30 } } })        // driver mpg
      .mockResolvedValueOnce({ data: { data: bookingsData } });       // bookings

    // POST calls: routing service for direct distance
    axiosPost.mockResolvedValueOnce({ data: { distance_miles: 5 } });

    const { default: app } = await import('../../services/cost-calculation-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{
      status: string;
      data: {
        trip_id: string;
        rider_count: number;
        riders: Array<{ rider_id: string }>;
      };
    }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/cost/settle/trip-123',
    });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data.trip_id).toBe('trip-123');
    expect(res.body.data.rider_count).toBe(2);
    expect(res.body.data.riders).toHaveLength(2);
  });

  it('uses default MPG (25) when the driver fetch fails', async () => {
    const tripData = {
      trip_id:     'trip-456',
      driver_id:   'driver-002',
      origin:      'SJSU',
      destination: 'Airport',
    };

    axiosGet
      .mockResolvedValueOnce({ data: { data: tripData } })          // trip
      .mockRejectedValueOnce(new Error('user-service unavailable')) // driver mpg fails
      .mockResolvedValueOnce({ data: [] });                          // empty bookings

    axiosPost.mockResolvedValueOnce({ data: { distance_miles: 8 } });

    const { default: app } = await import('../../services/cost-calculation-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{
      status: string;
      data: { driver_mpg: number };
    }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/cost/settle/trip-456',
    });

    expect(res.status).toBe(200);
    expect(res.body.data.driver_mpg).toBe(25);
  });

  it('excludes cancelled/rejected bookings from rider count', async () => {
    const tripData = {
      trip_id: 'trip-789', driver_id: 'drv-3', origin: 'A', destination: 'B',
    };

    const bookingsData = [
      { rider_id: 'r1', rider_name: 'Alice', seats_booked: 1, status: 'confirmed' },
      { rider_id: 'r2', rider_name: 'Bob',   seats_booked: 1, status: 'cancelled' },
      { rider_id: 'r3', rider_name: 'Carol', seats_booked: 1, status: 'rejected'  },
    ];

    axiosGet
      .mockResolvedValueOnce({ data: { data: tripData } })
      .mockResolvedValueOnce({ data: { data: { mpg: 25 } } })
      .mockResolvedValueOnce({ data: { data: bookingsData } });

    axiosPost.mockResolvedValueOnce({ data: { distance_miles: 3 } });

    const { default: app } = await import('../../services/cost-calculation-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{
      status: string;
      data: { rider_count: number; riders: unknown[] };
    }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/cost/settle/trip-789',
    });

    expect(res.status).toBe(200);
    expect(res.body.data.rider_count).toBe(1);
    expect(res.body.data.riders).toHaveLength(1);
  });

  it('uses 10-mile default when the routing service is unavailable for settlement', async () => {
    const tripData = {
      trip_id: 'trip-def', driver_id: 'drv-4', origin: 'X', destination: 'Y',
    };

    axiosGet
      .mockResolvedValueOnce({ data: { data: tripData } })
      .mockResolvedValueOnce({ data: { data: { mpg: 20 } } })
      .mockResolvedValueOnce({ data: [] });

    axiosPost.mockRejectedValueOnce(new Error('routing unavailable'));

    const { default: app } = await import('../../services/cost-calculation-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{
      status: string;
      data: { breakdown: { direct_distance_miles: number } };
    }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/cost/settle/trip-def',
    });

    expect(res.status).toBe(200);
    expect(res.body.data.breakdown.direct_distance_miles).toBe(10);
  });
});
