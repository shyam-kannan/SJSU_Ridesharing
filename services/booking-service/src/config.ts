import dotenv from 'dotenv';
import { getSecretValue } from '@lessgo/shared';

dotenv.config();

export const config = {
  port: process.env.BOOKING_SERVICE_PORT || 3004,
  env: process.env.NODE_ENV || 'development',

  // Database
  databaseUrl: getSecretValue('DATABASE_URL'),

  // JWT
  jwtSecret: getSecretValue('JWT_SECRET', 'default-secret-change-in-production'),

  // Service URLs
  tripServiceUrl: process.env.TRIP_SERVICE_URL || 'http://127.0.0.1:3003',
  paymentServiceUrl: process.env.PAYMENT_SERVICE_URL || 'http://127.0.0.1:3005',
  costServiceUrl: process.env.COST_SERVICE_URL || 'http://127.0.0.1:3009',
  notificationServiceUrl: process.env.NOTIFICATION_SERVICE_URL || 'http://127.0.0.1:3006',
};

if (!config.databaseUrl) {
  throw new Error('DATABASE_URL environment variable is required');
}
