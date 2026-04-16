import { beforeEach, describe, expect, it, vi } from 'vitest';
import { SJSUIdStatus, UserRole } from '../../shared/types';

describe('services/auth-service security helpers', () => {
  beforeEach(() => {
    vi.resetModules();
    process.env.DATABASE_URL = 'postgres://test-db-url';
    process.env.JWT_SECRET = 'unit-test-secret';
    process.env.JWT_ACCESS_EXPIRY = '15m';
    process.env.JWT_REFRESH_EXPIRY = '7d';
  });

  it('hashes and verifies passwords', async () => {
    const { hashPassword, comparePassword } = await import(
      '../../services/auth-service/src/services/bcrypt.service'
    );

    const password = 'ValidPass123';
    const hash = await hashPassword(password);

    expect(hash).not.toBe(password);
    await expect(comparePassword(password, hash)).resolves.toBe(true);
    await expect(comparePassword('WrongPass123', hash)).resolves.toBe(false);
  });

  it('generates and verifies an access token payload', async () => {
    const { generateAccessToken, verifyToken } = await import(
      '../../services/auth-service/src/services/jwt.service'
    );

    const token = generateAccessToken(
      '123e4567-e89b-12d3-a456-426614174000',
      'student@sjsu.edu',
      UserRole.Rider,
      SJSUIdStatus.Verified
    );

    const decoded = verifyToken(token);
    expect(decoded.userId).toBe('123e4567-e89b-12d3-a456-426614174000');
    expect(decoded.email).toBe('student@sjsu.edu');
    expect(decoded.role).toBe(UserRole.Rider);
    expect(decoded.sjsuIdStatus).toBe(SJSUIdStatus.Verified);
    expect(decoded.type).toBe('access');
  });

  it('creates a token pair with expected token types', async () => {
    const { generateTokenPair, verifyToken } = await import(
      '../../services/auth-service/src/services/jwt.service'
    );

    const pair = generateTokenPair(
      '123e4567-e89b-12d3-a456-426614174001',
      'driver@sjsu.edu',
      UserRole.Driver,
      SJSUIdStatus.Pending
    );

    const accessPayload = verifyToken(pair.accessToken);
    const refreshPayload = verifyToken(pair.refreshToken);

    expect(accessPayload.type).toBe('access');
    expect(refreshPayload.type).toBe('refresh');
    expect(refreshPayload.userId).toBe('123e4567-e89b-12d3-a456-426614174001');
  });
});
