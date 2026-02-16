// Types and enums
export * from './types';

// Middleware
export { authenticateToken, requireVerifiedStudent, requireDriver } from './middleware/auth';
export type { AuthRequest } from './middleware/auth';
export { AppError, errorHandler, notFoundHandler, asyncHandler } from './middleware/errorHandler';
export { requestLogger, devLogger } from './middleware/logger';
export { corsMiddleware, devCorsMiddleware } from './middleware/cors';

// Utilities
export { successResponse, errorResponse, paginatedResponse } from './utils/response';
export {
  isValidEmail,
  isValidSJSUEmail,
  isValidUUID,
  validatePassword,
  isValidLatitude,
  isValidLongitude,
  isValidPhone,
  sanitizeString,
  isValidRating,
  isPositiveInteger,
  isFutureDate,
} from './utils/validation';

// Database
export { query, getClient, transaction, closePool } from './database/connection';
export { default as pool } from './database/connection';
