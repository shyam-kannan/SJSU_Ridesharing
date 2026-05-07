import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { getSecretValue } from '../utils/secrets';
import { JWTPayload } from '../types';
import { errorResponse } from '../utils/response';

/**
 * Extended Express Request interface with user data from JWT
 */
export interface AuthRequest extends Request {
  user?: {
    userId: string;
    email: string;
    role: 'Driver' | 'Rider';
    sjsuIdStatus?: 'pending' | 'verified' | 'rejected';
  };
}

/**
 * Middleware to authenticate JWT token
 * Verifies the token and attaches user data to the request object
 * @param req Express request object with AuthRequest extension
 * @param res Express response object
 * @param next Express next function
 */
export const authenticateToken = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    errorResponse(res, 'Access token required', 401);
    return;
  }

  try {
    const jwtSecret = getSecretValue('JWT_SECRET');
    if (!jwtSecret) {
      throw new Error('JWT_SECRET not configured');
    }

    const decoded = jwt.verify(token, jwtSecret) as JWTPayload;

    // Check if token is access token (not refresh token)
    if (decoded.type !== 'access') {
      errorResponse(res, 'Invalid token type. Access token required', 403);
      return;
    }

    // Attach user data to request
    req.user = {
      userId: decoded.userId,
      email: decoded.email,
      role: decoded.role,
      sjsuIdStatus: decoded.sjsuIdStatus,
    };

    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      errorResponse(res, 'Token expired', 401);
      return;
    }

    if (error instanceof jwt.JsonWebTokenError) {
      errorResponse(res, 'Invalid token', 403);
      return;
    }

    errorResponse(res, 'Internal server error during authentication', 500);
  }
};

/**
 * Middleware to verify user has verified SJSU ID
 * Must be used after authenticateToken
 *
 * DEV BYPASS: In non-production environments, accounts whose email starts with
 * "sim-" or "devtools-" skip this check so simulation/devtools flows work
 * without real SJSU credentials.
 *
 * @param req Express request object with AuthRequest extension
 * @param res Express response object
 * @param next Express next function
 */
export const requireVerifiedStudent = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void => {
  if (!req.user) {
    errorResponse(res, 'Authentication required', 401);
    return;
  }

  // Dev-only bypass for simulation accounts (sim-* and devtools-* prefixes).
  // Never active in production.
  const isDevSimAccount =
    process.env.NODE_ENV !== 'production' &&
    (req.user.email.startsWith('sim-') || req.user.email.startsWith('devtools-'));

  if (isDevSimAccount) {
    next();
    return;
  }

  if (req.user.sjsuIdStatus !== 'verified') {
    errorResponse(
      res,
      'SJSU ID verification required to access this resource',
      403,
      { sjsuIdStatus: req.user.sjsuIdStatus || 'unverified' }
    );
    return;
  }

  next();
};

/**
 * Middleware to verify user is a driver
 * Must be used after authenticateToken
 * @param req Express request object with AuthRequest extension
 * @param res Express response object
 * @param next Express next function
 */
export const requireDriver = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void => {
  if (!req.user) {
    errorResponse(res, 'Authentication required', 401);
    return;
  }

  if (req.user.role !== 'Driver') {
    errorResponse(res, 'Driver role required to access this resource', 403);
    return;
  }

  next();
};
