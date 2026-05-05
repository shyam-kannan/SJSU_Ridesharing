import { Request, Response, NextFunction } from 'express';
import { ValidationError } from '../types';

/**
 * Custom Application Error class
 * Extends Error with additional properties for API error handling
 */
export class AppError extends Error {
  statusCode: number;
  isOperational: boolean;
  errors?: ValidationError[] | Record<string, string>;

  constructor(
    message: string,
    statusCode: number = 500,
    errors?: ValidationError[] | Record<string, string>
  ) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    this.errors = errors;
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Global error handling middleware
 * Catches all errors and returns standardized error responses
 * @param err Error object (can be AppError or generic Error)
 * @param req Express request object
 * @param res Express response object
 * @param next Express next function
 */
export const errorHandler = (
  err: Error | AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Check if error is operational (known error)
  if (err instanceof AppError && err.isOperational) {
    res.status(err.statusCode).json({
      status: 'error',
      message: err.message,
      errors: err.errors,
    });
    return;
  }

  // Log unexpected errors
  console.error('❌ UNEXPECTED ERROR:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    body: req.body,
    correlationId: req.headers['x-correlation-id'],
  });

  // Return generic error message for unexpected errors
  res.status(500).json({
    status: 'error',
    message: 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && {
      error: err.message,
      stack: err.stack,
    }),
  });
};

/**
 * 404 Not Found handler
 * Should be placed after all routes to catch unmatched routes
 * @param req Express request object
 * @param res Express response object
 * @param next Express next function
 */
export const notFoundHandler = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  res.status(404).json({
    status: 'error',
    message: `Route ${req.method} ${req.url} not found`,
  });
};

/**
 * Async route handler wrapper
 * Automatically catches errors in async route handlers and passes to error middleware
 * @param fn Async route handler function
 * @returns Wrapped function that catches errors
 * @example
 * ```ts
 * app.get('/users', asyncHandler(async (req, res) => {
 *   const users = await getUsers();
 *   res.json(users);
 * }));
 * ```
 */
export const asyncHandler = (
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>
) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};
