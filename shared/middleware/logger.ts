import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';

/**
 * Request logging middleware
 * Logs all incoming requests with correlation ID for tracking
 */
export const requestLogger = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Generate or use existing correlation ID for request tracking
  const correlationId = (req.headers['x-correlation-id'] as string) || uuidv4();

  // Attach correlation ID to request headers
  req.headers['x-correlation-id'] = correlationId;

  // Add correlation ID to response headers
  res.setHeader('x-correlation-id', correlationId);

  const start = Date.now();

  // Log request details
  console.log(`📨 Incoming Request [${correlationId}]:`, {
    method: req.method,
    url: req.url,
    ip: req.ip || req.socket.remoteAddress,
    userAgent: req.headers['user-agent'],
    timestamp: new Date().toISOString(),
  });

  // Log response when finished
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logLevel = res.statusCode >= 400 ? '❌' : '✅';

    console.log(`${logLevel} Response [${correlationId}]:`, {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      timestamp: new Date().toISOString(),
    });
  });

  next();
};

/**
 * Development mode detailed logger
 * Logs request body and query params (only for development)
 */
export const devLogger = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (process.env.NODE_ENV === 'development') {
    console.log('📋 Request Details:', {
      body: req.body,
      query: req.query,
      params: req.params,
    });
  }
  next();
};
