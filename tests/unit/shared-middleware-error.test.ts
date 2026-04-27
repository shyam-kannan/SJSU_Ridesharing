import { afterEach, describe, expect, it, vi } from 'vitest';
import express from 'express';
import { requestJson, startTestServer } from './http-test-utils';
import { AppError, errorHandler, notFoundHandler, asyncHandler } from '../../shared/middleware/errorHandler';

let closeServer: (() => Promise<void>) | null = null;

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

// ── AppError ─────────────────────────────────────────────────────────────────

describe('shared/middleware/errorHandler > AppError', () => {
  it('stores the message, statusCode, and isOperational flag', () => {
    const err = new AppError('Not found', 404);
    expect(err.message).toBe('Not found');
    expect(err.statusCode).toBe(404);
    expect(err.isOperational).toBe(true);
    expect(err instanceof Error).toBe(true);
  });

  it('defaults statusCode to 500 when none is provided', () => {
    const err = new AppError('Unexpected');
    expect(err.statusCode).toBe(500);
  });

  it('stores extra validation errors when provided', () => {
    const errors = { field: 'email', msg: 'required' };
    const err = new AppError('Validation error', 422, errors);
    expect(err.errors).toEqual(errors);
  });
});

// ── errorHandler ─────────────────────────────────────────────────────────────

describe('shared/middleware/errorHandler > errorHandler', () => {
  function buildApp(throwFn: () => void) {
    const app = express();
    app.get('/boom', (_req, _res, next) => {
      try {
        throwFn();
      } catch (e) {
        next(e);
      }
    });
    app.use(errorHandler);
    return app;
  }

  it('returns the AppError status and message for operational errors', async () => {
    const app = buildApp(() => {
      throw new AppError('Resource not found', 404);
    });
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/boom',
    });

    expect(res.status).toBe(404);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toBe('Resource not found');
  });

  it('includes errors payload when AppError carries one', async () => {
    const app = buildApp(() => {
      throw new AppError('Validation failed', 422, { email: 'required' });
    });
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ errors: unknown }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/boom',
    });

    expect(res.status).toBe(422);
    expect(res.body.errors).toEqual({ email: 'required' });
  });

  it('returns 500 for non-operational (unexpected) errors', async () => {
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const app = buildApp(() => {
      throw new Error('Something unexpected blew up');
    });
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/boom',
    });

    expect(res.status).toBe(500);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toBe('Internal server error');
    consoleSpy.mockRestore();
  });
});

// ── notFoundHandler ───────────────────────────────────────────────────────────

describe('shared/middleware/errorHandler > notFoundHandler', () => {
  it('returns 404 with a message describing the missing route', async () => {
    const app = express();
    app.use(notFoundHandler);
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/does-not-exist',
    });

    expect(res.status).toBe(404);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toContain('/does-not-exist');
    expect(res.body.message).toContain('GET');
  });
});

// ── asyncHandler ──────────────────────────────────────────────────────────────

describe('shared/middleware/errorHandler > asyncHandler', () => {
  it('forwards async errors to the error handler', async () => {
    const app = express();
    app.get(
      '/async-boom',
      asyncHandler(async (_req: express.Request, _res: express.Response) => {
        throw new AppError('Async failure', 503);
      })
    );
    app.use(errorHandler);
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/async-boom',
    });

    expect(res.status).toBe(503);
    expect(res.body.message).toBe('Async failure');
  });

  it('does not interfere with successful async handlers', async () => {
    const app = express();
    app.use(express.json());
    app.get(
      '/async-ok',
      asyncHandler(async (_req: express.Request, res: express.Response) => {
        res.json({ ok: true });
      })
    );
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ ok: boolean }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/async-ok',
    });

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });
});
