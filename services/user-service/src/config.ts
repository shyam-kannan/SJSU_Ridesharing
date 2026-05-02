import dotenv from 'dotenv';
import { getSecretValue } from '@lessgo/shared';

dotenv.config();

export const config = {
  port: process.env.USER_SERVICE_PORT || 3002,
  env: process.env.NODE_ENV || 'development',

  // Database
  databaseUrl: getSecretValue('DATABASE_URL'),

  // JWT (for authentication middleware)
  jwtSecret: getSecretValue('JWT_SECRET', 'default-secret-change-in-production'),
};

// Validate required config
if (!config.databaseUrl) {
  throw new Error('DATABASE_URL environment variable is required');
}
