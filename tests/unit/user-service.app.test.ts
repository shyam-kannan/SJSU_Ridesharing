import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;

beforeEach(() => {
  vi.resetModules();
  process.env.DATABASE_URL = 'postgres://user-test-db';
  process.env.JWT_SECRET = 'user-service-test-secret';
  process.env.NODE_ENV = 'test';
});

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

describe('services/user-service > health check', () => {
  it('returns health status for user service', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; service: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/health',
    });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.service).toBe('user-service');
  });
});

describe('services/user-service > route protections', () => {
  it('requires authentication for GET /users/me', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/users/me',
    });

    expect(res.status).toBe(401);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toBe('Access token required');
  });

  it('requires authentication for PUT /users/:id', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'PUT',
      path: '/users/123e4567-e89b-12d3-a456-426614174000',
      body: { name: 'Alice' },
    });

    expect(res.status).toBe(401);
    expect(res.body.status).toBe('error');
  });

  it('requires authentication for PUT /users/:id/driver-setup', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'PUT',
      path: '/users/123e4567-e89b-12d3-a456-426614174000/driver-setup',
      body: { vehicle_info: 'Tesla Model 3', seats_available: 3 },
    });

    expect(res.status).toBe(401);
  });

  it('requires authentication for GET /users/:id/earnings', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/users/123e4567-e89b-12d3-a456-426614174000/earnings',
    });

    expect(res.status).toBe(401);
  });

  it('requires authentication for PATCH /users/:id/availability', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'PATCH',
      path: '/users/123e4567-e89b-12d3-a456-426614174000/availability',
      body: { available: true },
    });

    expect(res.status).toBe(401);
  });
});

describe('services/user-service > vehicle lookup validation', () => {
  it('returns 400 when make or year is missing from GET /vehicles/models', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/vehicles/models?make=Toyota',
    });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toContain('year');
  });

  it('returns 400 for an out-of-range year on GET /vehicles/models', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/vehicles/models?make=Toyota&year=1800',
    });

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('year');
  });

  it('returns 400 when make, model, or year is missing from GET /vehicles/specs', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/vehicles/specs?make=Toyota',
    });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
  });

  it('returns 400 when make or model is missing from GET /vehicles/photo', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/vehicles/photo?make=Toyota',
    });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
  });
});

describe('services/user-service > 404 for unknown routes', () => {
  it('returns 404 for a completely unknown path', async () => {
    const { default: app } = await import('../../services/user-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/nonexistent',
    });

    expect(res.status).toBe(404);
    expect(res.body.status).toBe('error');
  });
});
