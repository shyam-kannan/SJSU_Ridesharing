import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

beforeEach(() => {
  process.env.JWT_SECRET = 'gateway-public-path-test-secret';
});

describe('services/api-gateway > public auth paths bypass JWT', () => {
  it('does not return 401 for POST /api/auth/login (proxied, returns 502 without service)', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/api/auth/login',
      body: { email: 'student@sjsu.edu', password: 'TestPass1' },
    });

    // 401 means our gateway rejected it; any other status means it passed JWT and tried to proxy
    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });

  it('does not return 401 for POST /api/auth/register', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/api/auth/register',
      body: { email: 'new@sjsu.edu', password: 'TestPass1', name: 'New User' },
    });

    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });

  it('does not return 401 for POST /api/auth/refresh', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/api/auth/refresh',
      body: { refreshToken: 'any-token' },
    });

    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });
});

describe('services/api-gateway > public trips GET path bypasses JWT', () => {
  it('does not return 401 for GET /api/trips without a token', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/api/trips',
    });

    // Should reach proxy (502) rather than being blocked by JWT (401)
    expect(res.status).not.toBe(401);
  });
});

describe('services/api-gateway > public vehicles path bypasses JWT', () => {
  it('does not return 401 for GET /api/vehicles without a token', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/api/vehicles/makes',
    });

    expect(res.status).not.toBe(401);
  });
});

describe('services/api-gateway > protected routes still require auth', () => {
  it('returns 401 for POST /api/trips without a token', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/api/trips',
      body: { origin: 'SJSU', destination: 'Caltrain' },
    });

    expect(res.status).toBe(401);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toBe('Access token required');
  });

  it('returns 401 for GET /api/users/me without a token', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/api/users/me',
    });

    expect(res.status).toBe(401);
  });

  it('returns 401 for GET /api/notifications without a token', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/api/notifications/user/someone',
    });

    expect(res.status).toBe(401);
  });
});

describe('services/api-gateway > 404 for completely unknown routes', () => {
  it('returns 404 for a route that does not exist', async () => {
    const server = await startTestServer((await import('../../services/api-gateway/src/app')).default);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/totally-unknown',
    });

    expect(res.status).toBe(404);
    expect(res.body.status).toBe('error');
  });
});
