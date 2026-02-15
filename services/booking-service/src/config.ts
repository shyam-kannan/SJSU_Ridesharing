import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: process.env.BOOKING_SERVICE_PORT || 3004,
  env: process.env.NODE_ENV || 'development',

  // Database
  databaseUrl: process.env.DATABASE_URL,

  // JWT
  jwtSecret: process.env.JWT_SECRET || 'default-secret-change-in-production',

  // Service URLs
  paymentServiceUrl: process.env.PAYMENT_SERVICE_URL || 'http://localhost:3005',
  costServiceUrl: process.env.COST_SERVICE_URL || 'http://localhost:3009',
};

if (!config.databaseUrl) {
  throw new Error('DATABASE_URL environment variable is required');
}
