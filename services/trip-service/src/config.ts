import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: process.env.TRIP_SERVICE_PORT || 3003,
  env: process.env.NODE_ENV || 'development',

  // Database
  databaseUrl: process.env.DATABASE_URL,

  // JWT (for authentication middleware)
  jwtSecret: process.env.JWT_SECRET || 'default-secret-change-in-production',

  // Google Maps API
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY,

  // Geospatial defaults
  defaultSearchRadius: 5000, // 5km in meters
  maxSearchRadius: 50000, // 50km maximum
};

// Validate required config
if (!config.databaseUrl) {
  throw new Error('DATABASE_URL environment variable is required');
}

if (!config.googleMapsApiKey) {
  console.warn('⚠️  GOOGLE_MAPS_API_KEY not set. Geocoding will not work.');
}
