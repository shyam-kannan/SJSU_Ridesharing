import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

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
 */
export const authenticateToken = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    res.status(401).json({
      status: 'error',
      message: 'Access token required',
    });
    return;
  }

  try {
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      throw new Error('JWT_SECRET not configured');
    }

    const decoded = jwt.verify(token, jwtSecret) as any;

    // Check if token is access token (not refresh token)
    if (decoded.type !== 'access') {
      res.status(403).json({
        status: 'error',
        message: 'Invalid token type. Access token required',
      });
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
      res.status(401).json({
        status: 'error',
        message: 'Token expired',
      });
      return;
    }

    if (error instanceof jwt.JsonWebTokenError) {
      res.status(403).json({
        status: 'error',
        message: 'Invalid token',
      });
      return;
    }

    res.status(500).json({
      status: 'error',
      message: 'Internal server error during authentication',
    });
  }
};

/**
 * Middleware to verify user has verified SJSU ID
 * Must be used after authenticateToken
 */
export const requireVerifiedStudent = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void => {
  if (!req.user) {
    res.status(401).json({
      status: 'error',
      message: 'Authentication required',
    });
    return;
  }

  if (req.user.sjsuIdStatus !== 'verified') {
    res.status(403).json({
      status: 'error',
      message: 'SJSU ID verification required to access this resource',
      sjsuIdStatus: req.user.sjsuIdStatus,
    });
    return;
  }

  next();
};

/**
 * Middleware to verify user is a driver
 * Must be used after authenticateToken
 */
export const requireDriver = (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): void => {
  if (!req.user) {
    res.status(401).json({
      status: 'error',
      message: 'Authentication required',
    });
    return;
  }

  if (req.user.role !== 'Driver') {
    res.status(403).json({
      status: 'error',
      message: 'Driver role required to access this resource',
    });
    return;
  }

  next();
};
