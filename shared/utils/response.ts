import { Response } from 'express';

/**
 * Standard success response format
 * @param res Express response object
 * @param data Data to return
 * @param message Success message
 * @param statusCode HTTP status code (default 200)
 */
export const successResponse = (
  res: Response,
  data: any,
  message: string = 'Success',
  statusCode: number = 200
): Response => {
  return res.status(statusCode).json({
    status: 'success',
    message,
    data,
  });
};

/**
 * Standard error response format
 * @param res Express response object
 * @param message Error message
 * @param statusCode HTTP status code (default 400)
 * @param errors Optional validation errors object
 */
export const errorResponse = (
  res: Response,
  message: string,
  statusCode: number = 400,
  errors?: any
): Response => {
  const response: any = {
    status: 'error',
    message,
  };

  if (errors) {
    response.errors = errors;
  }

  return res.status(statusCode).json(response);
};

/**
 * Paginated response format
 * @param res Express response object
 * @param data Array of data items
 * @param page Current page number
 * @param limit Items per page
 * @param total Total number of items
 * @param message Success message
 */
export const paginatedResponse = (
  res: Response,
  data: any[],
  page: number,
  limit: number,
  total: number,
  message: string = 'Success'
): Response => {
  const totalPages = Math.ceil(total / limit);
  const hasNext = page < totalPages;
  const hasPrev = page > 1;

  return res.status(200).json({
    status: 'success',
    message,
    data,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNext,
      hasPrev,
    },
  });
};
