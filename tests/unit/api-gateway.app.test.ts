import { afterEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';
import app from '../../services/api-gateway/src/app';

let closeServer: (() => Promise<void>) | null = null;

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

describe('services/api-gateway/src/app', () => {
  it('returns health status and service map', async () => {
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; services: Record<string, string> }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/health',
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.services.auth).toContain('127.0.0.1:3001');
  });

  it('blocks protected API routes when bearer token is missing', async () => {
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/api/bookings',
      body: { any: 'payload' },
    });

    expect(response.status).toBe(401);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('Access token required');
  });

  it('forwards protected routes with a bearer token to downstream services', async () => {
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/api/bookings',
      headers: { authorization: 'Bearer not-a-real-jwt' },
      body: { any: 'payload' },
    });

    expect(response.status).toBe(502);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('Service temporarily unavailable');
  });
});
