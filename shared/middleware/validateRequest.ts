import { Request, Response, NextFunction } from 'express';
import { validationResult } from 'express-validator';
import { ValidationError } from '../types';
import { errorResponse } from '../utils/response';

/**
 * Middleware to validate request using express-validator
 * Checks for validation errors and returns a formatted error response if found
 * @param req Express request object
 * @param res Express response object
 * @param next Express next function
 */
export const validateRequest = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const result = validationResult(req);

  if (result.isEmpty()) {
    next();
    return;
  }

  const errors: ValidationError[] = result.array().map((e) => ({
    field: 'path' in e ? e.path : undefined,
    message: e.msg,
  }));

  errorResponse(res, 'Validation failed', 400, errors);
};

