import { Request, Response, NextFunction } from 'express';
import { validationResult } from 'express-validator';

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

  res.status(400).json({
    status: 'error',
    message: 'Validation failed',
    errors: result.array().map((e) => ({
      field: 'path' in e ? e.path : undefined,
      message: e.msg,
    })),
  });
};

