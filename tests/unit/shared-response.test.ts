import { describe, expect, it, vi } from 'vitest';
import { errorResponse, paginatedResponse, successResponse } from '../../shared/utils/response';

const createResponseMock = () => {
  const json = vi.fn();
  const status = vi.fn(() => ({ json }));

  return {
    status,
    json,
  };
};

describe('shared/utils/response', () => {
  it('formats a success response with defaults', () => {
    const res = createResponseMock();

    const result = successResponse(res as any, { userId: '123' });

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      status: 'success',
      message: 'Success',
      data: { userId: '123' },
    });
    expect(result).toBeUndefined();
  });

  it('formats a success response with a custom status and message', () => {
    const res = createResponseMock();

    successResponse(res as any, { created: true }, 'Created', 201);

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith({
      status: 'success',
      message: 'Created',
      data: { created: true },
    });
  });

  it('formats an error response without optional details', () => {
    const res = createResponseMock();

    errorResponse(res as any, 'Validation failed');

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      status: 'error',
      message: 'Validation failed',
    });
  });

  it('includes validation errors when provided', () => {
    const res = createResponseMock();

    errorResponse(res as any, 'Invalid payload', 422, { email: 'required' });

    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith({
      status: 'error',
      message: 'Invalid payload',
      errors: { email: 'required' },
    });
  });

  it('returns pagination metadata for list responses', () => {
    const res = createResponseMock();

    paginatedResponse(res as any, [{ id: 'a' }, { id: 'b' }], 2, 10, 31, 'Trips loaded');

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      status: 'success',
      message: 'Trips loaded',
      data: [{ id: 'a' }, { id: 'b' }],
      pagination: {
        page: 2,
        limit: 10,
        total: 31,
        totalPages: 4,
        hasNext: true,
        hasPrev: true,
      },
    });
  });
});