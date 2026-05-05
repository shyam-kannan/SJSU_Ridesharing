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

describe('services/booking-service route protections', () => {
  it('returns health status for booking service', async () => {
    const { default: app } = await import('../../services/booking-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; service: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/health',
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.service).toBe('booking-service');
  });

  it('requires authentication for creating a booking', async () => {
    const { default: app } = await import('../../services/booking-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/bookings',
      body: {
        trip_id: '123e4567-e89b-12d3-a456-426614174111',
        seats_booked: 1,
      },
    });

    expect(response.status).toBe(401);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('Access token required');
  });
});
