import dotenv from 'dotenv';
import { getSecretValue } from '@lessgo/shared';

dotenv.config();

export const config = {
  port: process.env.AUTH_SERVICE_PORT || 3001,
  env: process.env.NODE_ENV || 'development',

  // Database
  databaseUrl: getSecretValue('DATABASE_URL'),

  // JWT
  jwtSecret: getSecretValue('JWT_SECRET', 'default-secret-change-in-production'),
  jwtAccessExpiry: getSecretValue('JWT_ACCESS_EXPIRY', '15m'),
  jwtRefreshExpiry: getSecretValue('JWT_REFRESH_EXPIRY', '7d'),

  // Bcrypt
  bcryptSaltRounds: 10,

  // File Upload
  uploadDir: process.env.UPLOAD_DIR || './uploads',
  sjsuIdUploadDir: process.env.UPLOAD_DIR ? `${process.env.UPLOAD_DIR}/sjsu-ids` : './uploads/sjsu-ids',
  maxFileSize: 5 * 1024 * 1024, // 5MB

  // AWS S3 (optional)
  awsS3Bucket: getSecretValue('AWS_S3_BUCKET'),
  awsRegion: getSecretValue('AWS_REGION'),
};

// Validate required config
if (!config.databaseUrl) {
  throw new Error('DATABASE_URL environment variable is required');
}

if (config.env === 'production' && config.jwtSecret === 'default-secret-change-in-production') {
  throw new Error('JWT_SECRET must be set in production');
}
