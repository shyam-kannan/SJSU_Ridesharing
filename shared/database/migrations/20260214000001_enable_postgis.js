/**
 * Migration: Enable PostGIS Extension
 * This enables PostGIS for geospatial queries on trips (origin/destination points)
 */

exports.up = (pgm) => {
  // Enable PostGIS extension for geospatial functionality
  pgm.sql('CREATE EXTENSION IF NOT EXISTS postgis;');

  console.log('PostGIS extension enabled successfully');
};

exports.down = (pgm) => {
  // Drop PostGIS extension (be careful with this in production)
  pgm.sql('DROP EXTENSION IF EXISTS postgis CASCADE;');
};
