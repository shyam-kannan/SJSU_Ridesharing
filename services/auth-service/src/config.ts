import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: process.env.AUTH_SERVICE_PORT || 3001,
  env: process.env.NODE_ENV || 'development',

  // Database
  databaseUrl: process.env.DATABASE_URL,

  // JWT
  jwtSecret: process.env.JWT_SECRET || 'default-secret-change-in-production',
  jwtAccessExpiry: process.env.JWT_ACCESS_EXPIRY || '15m',
  jwtRefreshExpiry: process.env.JWT_REFRESH_EXPIRY || '7d',

  // Bcrypt
  bcryptSaltRounds: 10,

  // File Upload
  uploadDir: process.env.UPLOAD_DIR || './uploads',
  sjsuIdUploadDir: process.env.UPLOAD_DIR ? `${process.env.UPLOAD_DIR}/sjsu-ids` : './uploads/sjsu-ids',
  maxFileSize: 5 * 1024 * 1024, // 5MB

  // AWS S3 (optional)
  awsS3Bucket: process.env.AWS_S3_BUCKET,
  awsRegion: process.env.AWS_REGION,
};

// Validate required config
if (!config.databaseUrl) {
  throw new Error('DATABASE_URL environment variable is required');
}

if (config.env === 'production' && config.jwtSecret === 'default-secret-change-in-production') {
  throw new Error('JWT_SECRET must be set in production');
}
