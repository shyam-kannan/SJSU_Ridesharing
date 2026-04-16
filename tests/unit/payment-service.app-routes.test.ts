import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';

let closeServer: (() => Promise<void>) | null = null;

beforeEach(() => {
  vi.resetModules();
  process.env.DATABASE_URL = 'postgres://payment-test-db';
  process.env.STRIPE_SECRET_KEY = 'sk_test_payment_key';
  process.env.NODE_ENV = 'test';
});

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

describe('services/payment-service route validation', () => {
  it('returns health status for payment service', async () => {
    const { default: app } = await import('../../services/payment-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; service: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/health',
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.service).toBe('payment-service');
  });

  it('validates required fields for payment intent creation', async () => {
    const { default: app } = await import('../../services/payment-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; message: string; errors: Array<{ msg: string }> }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/payments/create-intent',
      body: {
        booking_id: 'invalid-booking-id',
        amount: 0,
      },
    });

    expect(response.status).toBe(400);
    expect(response.body.status).toBe('error');
    expect(response.body.message).toBe('Validation failed');
    expect(response.body.errors.length).toBeGreaterThan(0);
  });
});
