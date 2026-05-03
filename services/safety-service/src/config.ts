import dotenv from 'dotenv';
import path from 'path';

// Load .env file from root
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

export const config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.SAFETY_SERVICE_PORT || '8005', 10),
  dbUrl: process.env.DATABASE_URL || 'postgresql://postgres:password@localhost:5432/lessgo_db',
  
  // Notification Service
  notificationServiceUrl: process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:8004',
  
  // Mapping
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || '',
  
  // Safety Thresholds
  routeDeviationThresholdMeters: parseInt(process.env.ROUTE_DEVIATION_THRESHOLD_METERS || '50', 10),
  speedTolerancePercent: parseInt(process.env.SPEED_TOLERANCE_PERCENT || '15', 10),
  speedAnomalyWindowSeconds: parseInt(process.env.SPEED_ANOMALY_WINDOW_SECONDS || '10', 10),
  locationPollIntervalSeconds: parseInt(process.env.LOCATION_POLL_INTERVAL_SECONDS || '5', 10),
};
