import dotenv from 'dotenv';
import { getSecretValue } from '@lessgo/shared';

dotenv.config();

const requireSecret = (key: string): string => {
  const value = getSecretValue(key);
  if (!value) {
    throw new Error(`${key} environment variable is required`);
  }
  return value;
};

export const config = {
  port: process.env.AUTH_SERVICE_PORT || 3001,
  env: process.env.NODE_ENV || 'development',

  // Database
  databaseUrl: requireSecret('DATABASE_URL'),

  // JWT
  jwtSecret: requireSecret('JWT_SECRET'),
  jwtAccessExpiry: getSecretValue('JWT_ACCESS_EXPIRY') ?? '15m',
  jwtRefreshExpiry: getSecretValue('JWT_REFRESH_EXPIRY') ?? '7d',

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
// Required secrets are validated by requireSecret during config construction.
