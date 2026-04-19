import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;

beforeEach(() => {
  vi.resetModules();
  process.env.DATABASE_URL = 'postgres://trip-test-db';
  process.env.GOOGLE_MAPS_API_KEY = 'trip-test-key';
  process.env.JWT_SECRET = 'trip-test-secret';
  process.env.NODE_ENV = 'test';
});

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

describe('services/trip-service route protections', () => {
  it('returns health status for trip service', async () => {
    const { default: app } = await import('../../services/trip-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; service: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/health',
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.service).toBe('trip-service');
  });

  it('requires authentication for creating a trip', async () => {
    const { default: app } = await import('../../services/trip-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/trips',
      body: {
        origin: 'SJSU',
        destination: 'Downtown San Jose',
        departure_time: new Date(Date.now() + 3_600_000).toISOString(),
        seats_available: 3,
      },
    });

    expect(response.status).toBe(401);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('Access token required');
  });
});
