import { afterEach, describe, expect, it, vi } from 'vitest';

const originalEnv = { ...process.env };

async function importFresh<T>(modulePath: string): Promise<T> {
  vi.resetModules();
  return import(modulePath) as Promise<T>;
}

afterEach(() => {
  process.env = { ...originalEnv };
  vi.resetModules();
});

describe('service config modules', () => {
  it('auth-service config throws when DATABASE_URL is missing', async () => {
    delete process.env.DATABASE_URL;

    await expect(importFresh('../../services/auth-service/src/config')).rejects.toThrow(
      'DATABASE_URL environment variable is required'
    );
  });

  it('auth-service config loads defaults and upload paths', async () => {
    process.env.DATABASE_URL = 'postgres://auth-db';
    process.env.UPLOAD_DIR = '/tmp/uploads';
    process.env.AUTH_SERVICE_PORT = '4010';

    const module = await importFresh<typeof import('../../services/auth-service/src/config')>(
      '../../services/auth-service/src/config'
    );

    expect(module.config.port).toBe('4010');
    expect(module.config.sjsuIdUploadDir).toBe('/tmp/uploads/sjsu-ids');
    expect(module.config.maxFileSize).toBe(5 * 1024 * 1024);
  });

  it('booking-service config uses local defaults for dependent service URLs', async () => {
    process.env.DATABASE_URL = 'postgres://booking-db';
    delete process.env.TRIP_SERVICE_URL;
    delete process.env.PAYMENT_SERVICE_URL;
    delete process.env.COST_SERVICE_URL;
    delete process.env.NOTIFICATION_SERVICE_URL;

    const module = await importFresh<typeof import('../../services/booking-service/src/config')>(
      '../../services/booking-service/src/config'
    );

    expect(module.config.tripServiceUrl).toBe('http://127.0.0.1:3003');
    expect(module.config.paymentServiceUrl).toBe('http://127.0.0.1:3005');
    expect(module.config.costServiceUrl).toBe('http://127.0.0.1:3009');
    expect(module.config.notificationServiceUrl).toBe('http://127.0.0.1:3006');
  });

  it('trip-service config loads geospatial defaults', async () => {
    process.env.DATABASE_URL = 'postgres://trip-db';
    process.env.GOOGLE_MAPS_API_KEY = 'maps-key';

    const module = await importFresh<typeof import('../../services/trip-service/src/config')>(
      '../../services/trip-service/src/config'
    );

    expect(module.config.defaultSearchRadius).toBe(100000);
    expect(module.config.maxSearchRadius).toBe(100000);
    expect(module.config.googleMapsApiKey).toBe('maps-key');
  });

  it('user-service config throws when DATABASE_URL is missing', async () => {
    delete process.env.DATABASE_URL;

    await expect(importFresh('../../services/user-service/src/config')).rejects.toThrow(
      'DATABASE_URL environment variable is required'
    );
  });

  it('payment-service config enforces required Stripe key', async () => {
    process.env.DATABASE_URL = 'postgres://payment-db';
    delete process.env.STRIPE_SECRET_KEY;

    await expect(importFresh('../../services/payment-service/src/config')).rejects.toThrow(
      'STRIPE_SECRET_KEY required'
    );
  });
});
