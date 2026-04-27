import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import express from 'express';
import jwt from 'jsonwebtoken';
import { requestJson, startTestServer } from './http-test-utils';

const TEST_SECRET = 'test-jwt-secret-auth-middleware';

function makeToken(payload: Record<string, unknown>, secret = TEST_SECRET, expiresIn = '1h') {
  return jwt.sign(payload, secret, { expiresIn } as jwt.SignOptions);
}

function makeAccessToken(
  userId = 'user-uuid-001',
  email = 'student@sjsu.edu',
  role: 'Driver' | 'Rider' = 'Rider',
  sjsuIdStatus: 'pending' | 'verified' | 'rejected' = 'verified'
) {
  return makeToken({ userId, email, role, sjsuIdStatus, type: 'access' });
}

let closeServer: (() => Promise<void>) | null = null;

beforeEach(() => {
  process.env.JWT_SECRET = TEST_SECRET;
});

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

// ── authenticateToken ─────────────────────────────────────────────────────────

describe('shared/middleware/auth > authenticateToken', () => {
  async function buildAuthApp() {
    const { authenticateToken } = await import('../../shared/middleware/auth');
    const app = express();
    app.get('/protected', authenticateToken, (req, res) => res.json({ ok: true }));
    return app;
  }

  it('returns 401 when Authorization header is absent', async () => {
    const app = await buildAuthApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson({ baseUrl: server.baseUrl, method: 'GET', path: '/protected' });
    expect(res.status).toBe(401);
    expect((res.body as any).message).toBe('Access token required');
  });

  it('returns 403 when token is malformed', async () => {
    const app = await buildAuthApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/protected',
      headers: { authorization: 'Bearer not-a-valid-jwt' },
    });
    expect(res.status).toBe(403);
    expect((res.body as any).message).toBe('Invalid token');
  });

  it('returns 401 when token is expired', async () => {
    const app = await buildAuthApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const expired = makeToken(
      { userId: 'u1', email: 'a@sjsu.edu', role: 'Rider', sjsuIdStatus: 'verified', type: 'access' },
      TEST_SECRET,
      '-1s'
    );

    const res = await requestJson({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/protected',
      headers: { authorization: `Bearer ${expired}` },
    });
    expect(res.status).toBe(401);
    expect((res.body as any).message).toBe('Token expired');
  });

  it('returns 403 when a refresh token is used instead of access token', async () => {
    const app = await buildAuthApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const refreshToken = makeToken({ userId: 'u1', type: 'refresh' });

    const res = await requestJson({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/protected',
      headers: { authorization: `Bearer ${refreshToken}` },
    });
    expect(res.status).toBe(403);
    expect((res.body as any).message).toBe('Invalid token type. Access token required');
  });

  it('calls next and attaches user when token is valid', async () => {
    const app = await buildAuthApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const token = makeAccessToken('user-001', 'driver@sjsu.edu', 'Driver', 'verified');

    const res = await requestJson<{ ok: boolean }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/protected',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });
});

// ── requireVerifiedStudent ────────────────────────────────────────────────────

describe('shared/middleware/auth > requireVerifiedStudent', () => {
  async function buildVerifiedApp() {
    const { authenticateToken, requireVerifiedStudent } = await import('../../shared/middleware/auth');
    const app = express();
    app.get('/verified', authenticateToken, requireVerifiedStudent, (req, res) =>
      res.json({ ok: true })
    );
    return app;
  }

  it('returns 403 with sjsuIdStatus when user is pending', async () => {
    const app = await buildVerifiedApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const token = makeAccessToken('u2', 'student@sjsu.edu', 'Rider', 'pending');

    const res = await requestJson({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/verified',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(403);
    expect((res.body as any).sjsuIdStatus).toBe('pending');
  });

  it('returns 403 when user is rejected', async () => {
    const app = await buildVerifiedApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const token = makeAccessToken('u3', 'student@sjsu.edu', 'Rider', 'rejected');

    const res = await requestJson({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/verified',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(403);
  });

  it('passes verification for a verified user', async () => {
    const app = await buildVerifiedApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const token = makeAccessToken('u4', 'student@sjsu.edu', 'Rider', 'verified');

    const res = await requestJson<{ ok: boolean }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/verified',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  it('bypasses SJSU ID check for sim- accounts in non-production', async () => {
    process.env.NODE_ENV = 'test';
    const app = await buildVerifiedApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const token = makeAccessToken('u5', 'sim-driver@sjsu.edu', 'Driver', 'pending');

    const res = await requestJson<{ ok: boolean }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/verified',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  it('does NOT bypass for sim- accounts in production', async () => {
    process.env.NODE_ENV = 'production';
    const app = await buildVerifiedApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const token = makeAccessToken('u6', 'sim-driver@sjsu.edu', 'Driver', 'pending');

    const res = await requestJson({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/verified',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(403);
    delete process.env.NODE_ENV;
  });
});

// ── requireDriver ─────────────────────────────────────────────────────────────

describe('shared/middleware/auth > requireDriver', () => {
  async function buildDriverApp() {
    const { authenticateToken, requireDriver } = await import('../../shared/middleware/auth');
    const app = express();
    app.get('/driver-only', authenticateToken, requireDriver, (req, res) =>
      res.json({ ok: true })
    );
    return app;
  }

  it('returns 403 when a Rider tries to access a Driver-only route', async () => {
    const app = await buildDriverApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const token = makeAccessToken('u7', 'rider@sjsu.edu', 'Rider', 'verified');

    const res = await requestJson({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/driver-only',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(403);
    expect((res.body as any).message).toBe('Driver role required to access this resource');
  });

  it('passes when the authenticated user is a Driver', async () => {
    const app = await buildDriverApp();
    const server = await startTestServer(app);
    closeServer = server.close;

    const token = makeAccessToken('u8', 'driver@sjsu.edu', 'Driver', 'verified');

    const res = await requestJson<{ ok: boolean }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/driver-only',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });
});
