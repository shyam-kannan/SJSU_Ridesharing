import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';
import { SJSUIdStatus, UserRole } from '../../shared/types';

const authServiceMocks = vi.hoisted(() => ({
  changePassword: vi.fn(),
  createUser: vi.fn(),
  findUserById: vi.fn(),
  submitSJSUIdImage: vi.fn(),
  toSafeUser: vi.fn(),
  updateSJSUIdStatus: vi.fn(),
  validateCredentials: vi.fn(),
}));

const jwtServiceMocks = vi.hoisted(() => ({
  generateAccessToken: vi.fn(),
  generateTokenPair: vi.fn(),
  verifyToken: vi.fn(),
}));

vi.mock('../../services/auth-service/src/services/auth.service', () => authServiceMocks);
vi.mock('../../services/auth-service/src/services/jwt.service', () => jwtServiceMocks);

let closeServer: (() => Promise<void>) | null = null;

const userRecord = {
  created_at: new Date('2026-01-01T00:00:00.000Z'),
  email: 'student@sjsu.edu',
  name: 'Student Rider',
  password_hash: 'hashed-password',
  rating: 5,
  role: UserRole.Rider,
  sjsu_id_status: SJSUIdStatus.Verified,
  updated_at: new Date('2026-01-01T00:00:00.000Z'),
  user_id: '123e4567-e89b-12d3-a456-426614174000',
};

const safeUser = {
  created_at: userRecord.created_at,
  email: userRecord.email,
  name: userRecord.name,
  rating: userRecord.rating,
  role: userRecord.role,
  sjsu_id_status: userRecord.sjsu_id_status,
  updated_at: userRecord.updated_at,
  user_id: userRecord.user_id,
};

async function startAuthApp() {
  const { default: app } = await import('../../services/auth-service/src/app');
  const server = await startTestServer(app);
  closeServer = server.close;
  return server;
}

beforeEach(() => {
  vi.resetModules();
  vi.clearAllMocks();

  process.env.DATABASE_URL = 'postgres://auth-test-db';
  process.env.JWT_SECRET = 'auth-service-test-secret';
  process.env.JWT_ACCESS_EXPIRY = '15m';
  process.env.JWT_REFRESH_EXPIRY = '7d';
  process.env.NODE_ENV = 'test';
  process.env.UPLOAD_DIR = '/tmp/lessgo-auth-service-tests';

  authServiceMocks.createUser.mockResolvedValue(userRecord);
  authServiceMocks.validateCredentials.mockResolvedValue(userRecord);
  authServiceMocks.findUserById.mockResolvedValue(userRecord);
  authServiceMocks.submitSJSUIdImage.mockResolvedValue(safeUser);
  authServiceMocks.toSafeUser.mockReturnValue(safeUser);
  authServiceMocks.changePassword.mockResolvedValue(undefined);
  authServiceMocks.updateSJSUIdStatus.mockResolvedValue({
    ...safeUser,
    sjsu_id_status: SJSUIdStatus.Verified,
  });

  jwtServiceMocks.generateTokenPair.mockReturnValue({
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  });
  jwtServiceMocks.generateAccessToken.mockReturnValue('new-access-token');
  jwtServiceMocks.verifyToken.mockReturnValue({
    email: userRecord.email,
    role: userRecord.role,
    sjsuIdStatus: userRecord.sjsu_id_status,
    type: 'access',
    userId: userRecord.user_id,
  });
});

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

describe('services/auth-service app routes', () => {
  it('returns health status for auth service', async () => {
    const server = await startAuthApp();

    const response = await requestJson<{ status: string; service: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/health',
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.service).toBe('auth-service');
  });

  it('rejects invalid registration payloads', async () => {
    const server = await startAuthApp();

    const response = await requestJson<{
      status: string;
      message: string;
      errors: Array<{ msg: string }>;
    }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/auth/register',
      body: {
        email: 'not-an-email',
        name: 'A',
        password: 'weak',
        role: 'Admin',
      },
    });

    expect(response.status).toBe(400);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('Validation failed');
    expect(response.body.errors.map((error) => error.msg)).toEqual(
      expect.arrayContaining([
        'Name must be between 2 and 255 characters',
        'Invalid email format',
        'Password must be at least 8 characters long',
        'Role must be either Driver or Rider',
      ])
    );
    expect(authServiceMocks.createUser).not.toHaveBeenCalled();
  });

  it('registers a user and returns a token pair', async () => {
    const server = await startAuthApp();

    const response = await requestJson<{
      status: string;
      data: { accessToken: string; refreshToken: string; user: { email: string } };
    }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/auth/register',
      body: {
        email: userRecord.email,
        name: userRecord.name,
        password: 'Password123',
        role: UserRole.Rider,
      },
    });

    expect(response.status).toBe(201);
    expect(response.body.status).toBe('success');
    expect(response.body.data.user.email).toBe(userRecord.email);
    expect(response.body.data.accessToken).toBe('access-token');
    expect(response.body.data.refreshToken).toBe('refresh-token');
    expect(authServiceMocks.createUser).toHaveBeenCalledWith(
      expect.objectContaining({
        email: userRecord.email,
        name: userRecord.name,
        role: UserRole.Rider,
      }),
      undefined
    );
    expect(jwtServiceMocks.generateTokenPair).toHaveBeenCalledWith(
      userRecord.user_id,
      userRecord.email,
      userRecord.role,
      userRecord.sjsu_id_status
    );
  });

  it('maps duplicate-email registration failures to a 400 response', async () => {
    authServiceMocks.createUser.mockRejectedValueOnce(
      new Error('An account with this email already exists')
    );
    const server = await startAuthApp();

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/auth/register',
      body: {
        email: userRecord.email,
        name: userRecord.name,
        password: 'Password123',
        role: UserRole.Rider,
      },
    });

    expect(response.status).toBe(400);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('An account with this email already exists');
  });

  it('returns 401 when login credentials are invalid', async () => {
    authServiceMocks.validateCredentials.mockResolvedValueOnce(null);
    const server = await startAuthApp();

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/auth/login',
      body: {
        email: userRecord.email,
        password: 'WrongPassword123',
      },
    });

    expect(response.status).toBe(401);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('Invalid email or password');
  });

  it('refreshes an access token for a valid refresh token', async () => {
    jwtServiceMocks.verifyToken.mockReturnValueOnce({
      type: 'refresh',
      userId: userRecord.user_id,
    });
    const server = await startAuthApp();

    const response = await requestJson<{ status: string; data: { accessToken: string } }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/auth/refresh',
      body: {
        refreshToken: 'refresh-token',
      },
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.data.accessToken).toBe('new-access-token');
    expect(jwtServiceMocks.generateAccessToken).toHaveBeenCalledWith(
      userRecord.user_id,
      userRecord.email,
      userRecord.role,
      userRecord.sjsu_id_status
    );
  });

  it('returns 403 when token verification fails for /auth/verify', async () => {
    jwtServiceMocks.verifyToken.mockImplementationOnce(() => {
      const error = new Error('invalid');
      error.name = 'JsonWebTokenError';
      throw error;
    });
    const server = await startAuthApp();

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/auth/verify',
      headers: {
        authorization: 'Bearer invalid-token',
      },
    });

    expect(response.status).toBe(403);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('Invalid token');
  });

  it('returns the current user for /auth/me when the token is valid', async () => {
    const server = await startAuthApp();

    const response = await requestJson<{ status: string; data: { user_id: string; email: string } }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/auth/me',
      headers: {
        authorization: 'Bearer access-token',
      },
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.data.user_id).toBe(userRecord.user_id);
    expect(response.body.data.email).toBe(userRecord.email);
    expect(authServiceMocks.toSafeUser).toHaveBeenCalledWith(userRecord);
  });

  it('validates change-password payloads before calling the service', async () => {
    const server = await startAuthApp();

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'PUT',
      path: '/auth/change-password',
      body: {
        currentPassword: 'Password123',
        newPassword: 'short',
      },
      headers: {
        authorization: 'Bearer access-token',
      },
    });

    expect(response.status).toBe(400);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('New password must be at least 8 characters');
    expect(authServiceMocks.changePassword).not.toHaveBeenCalled();
  });

  it('exposes the development-only test verification route outside production', async () => {
    const server = await startAuthApp();

    const response = await requestJson<{
      status: string;
      data: { user_id: string; sjsu_id_status: SJSUIdStatus };
    }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: `/auth/test/verify/${userRecord.user_id}`,
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.data.user_id).toBe(userRecord.user_id);
    expect(response.body.data.sjsu_id_status).toBe(SJSUIdStatus.Verified);
    expect(authServiceMocks.updateSJSUIdStatus).toHaveBeenCalledWith(
      userRecord.user_id,
      SJSUIdStatus.Verified
    );
  });
});
