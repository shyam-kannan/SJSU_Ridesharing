import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';

const axiosPost = vi.fn();

vi.mock('axios', () => ({
  default: {
    post: axiosPost,
  },
}));

let closeServer: (() => Promise<void>) | null = null;

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

beforeEach(() => {
  axiosPost.mockReset();
});

describe('services/cost-calculation-service/src/app', () => {
  it('returns health information', async () => {
    const { default: app } = await import('../../services/cost-calculation-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; service: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/health',
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.service).toBe('cost-calculation-service');
  });

  it('returns 400 for incomplete calculate payload', async () => {
    const { default: app } = await import('../../services/cost-calculation-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/cost/calculate',
      body: { origin: 'SJSU' },
    });

    expect(response.status).toBe(400);
    expect(response.body.status).toBe('error');
  });

  it('falls back to default distance when routing distance is unavailable', async () => {
    axiosPost.mockRejectedValueOnce(new Error('routing unavailable'));

    const { default: app } = await import('../../services/cost-calculation-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{
      status: string;
      data: { max_price: number; breakdown: { total_trip_cost: number; price_per_rider: number } };
    }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/cost/calculate',
      body: {
        origin: 'SJSU',
        destination: 'Mountain View',
        num_riders: 5,
        trip_id: 'trip-1',
      },
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.data.breakdown.total_trip_cost).toBe(10);
    expect(response.body.data.breakdown.price_per_rider).toBe(2);
    expect(response.body.data.max_price).toBe(2);
  });
});
