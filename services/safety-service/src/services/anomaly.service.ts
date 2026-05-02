import { getDistance, isPointNearLine } from 'geolib';
import { config } from '../config';
import { GeoPoint, getRideState, incrementAndGetSpeedViolations, resetSpeedViolations } from './tracking.service';
import { getSpeedLimitForLocation } from './speed-limit.service';
import { query } from '@lessgo/shared';
import { notifyUser } from './notification.service';

export interface AnomalyRecord {
  anomaly_id: string;
  trip_id: string;
  type: string;
  detected_at: Date;
  location: any;
  acknowledged: boolean;
  acknowledged_at: Date;
}

/**
 * Check for anomalies (route deviation and speed)
 */
export const checkAnomalies = async (
  ride_id: string,
  currentLocation: GeoPoint,
  currentSpeedMph: number, // Assuming frontend sends MPH for ease
  timestamp: Date
): Promise<string[]> => {
  const rideState = await getRideState(ride_id);
  if (!rideState) {
    throw new Error('Ride not found or not currently tracked');
  }

  const detectedAnomalies: string[] = [];
  const locationPg = `POINT(${currentLocation.lng} ${currentLocation.lat})`; // PostGIS uses Long Lat

  // 1. Check Route Deviation
  // geolib.isPointNearLine checks if the point is within X meters of ANY segment of the line.
  // Unfortunately geolib doesn't have a single "isPointNearRoute" that takes an array of points directly,
  // we have to check distance to the polyline paths.
  
  // We can optimize this by finding the minimum distance from the point to any segment in the planned_route.
  // Wait, geolib has a method `getDistanceFromLine(point, start, end)`
  // A simpler approach is to loop through the segments and find if distance < threshold.
  
  let isDeviated = true;
  for (let i = 0; i < rideState.planned_route.length - 1; i++) {
    const start = rideState.planned_route[i];
    const end = rideState.planned_route[i + 1];
    
    // Check if the current location is near this segment
    if (isPointNearLine(currentLocation, start, end, config.routeDeviationThresholdMeters)) {
      isDeviated = false;
      break;
    }
  }

  // If we iterated all segments and still true, then it's a deviation
  if (isDeviated && rideState.planned_route.length > 0) {
    // Only flag if route is defined
    detectedAnomalies.push('route_deviation');
    await logAnomaly(ride_id, 'route_deviation', locationPg);
    
    // Notify users
    // We would fetch driver and rider IDs from the booking-service or trip-service.
    // For now we assume we know them or we broadcast to a general ride topic.
    // In a real scenario you would join the trips table.
    try {
       const res = await query('SELECT driver_id FROM trips WHERE trip_id = $1', [ride_id]);
       if (res.rows.length > 0) {
         notifyUser(res.rows[0].driver_id, 'Route Deviation Alert', 'You have deviated significantly from the planned route.');
       }
       // Needs joined query to find riders in this trip
       const riderRes = await query('SELECT rider_id FROM bookings WHERE trip_id = $1', [ride_id]);
       for (const b of riderRes.rows) {
         notifyUser(b.rider_id, 'Route Deviation Alert', 'Your driver has deviated from the planned route.');
       }
    } catch(err) {
       console.error('Failed to notify users:', err);
    }
  }

  // 2. Check Speed Anomaly
  const limit = await getSpeedLimitForLocation(currentLocation.lat, currentLocation.lng);
  const maxAllowedSpeed = limit * (1 + (config.speedTolerancePercent / 100));

  if (currentSpeedMph > maxAllowedSpeed) {
    // Sustained speeding check
    const violations = await incrementAndGetSpeedViolations(ride_id, config.speedAnomalyWindowSeconds);
    
    // If we're polling every 5 seconds, 2 violations over 10 secs is sustained.
    // E.g., threshold = Window / PollInterval
    const requiredViolations = Math.floor(config.speedAnomalyWindowSeconds / config.locationPollIntervalSeconds);
    
    if (violations >= requiredViolations) {
      detectedAnomalies.push('speed_anomaly');
      await logAnomaly(ride_id, 'speed_anomaly', locationPg);
      
      // Notify driver only for speeding generally, but requirements say "Riders and drivers"
      try {
         const res = await query('SELECT driver_id FROM trips WHERE trip_id = $1', [ride_id]);
         if (res.rows.length > 0) {
           notifyUser(res.rows[0].driver_id, 'Speed Alert', `You are exceeding the speed limit of ${limit} mph.`);
         }
         const riderRes = await query('SELECT rider_id FROM bookings WHERE trip_id = $1', [ride_id]);
         for (const b of riderRes.rows) {
           notifyUser(b.rider_id, 'Speed Alert', 'Your driver is exceeding the speed limit.');
         }
      } catch(err) {
         console.error('Failed to notify users:', err);
      }
      
      // Reset after alerting to avoid spamming every polling tick, or we could require them to slow down
      // we'll reset it so the next alert happens after another 10 seconds of speeding
      await resetSpeedViolations(ride_id);
    }
  } else {
    // If they slowed down below the tolerance, reset the counter
    await resetSpeedViolations(ride_id);
  }

  return detectedAnomalies;
};

/**
 * Log the anomaly to the database
 */
const logAnomaly = async (ride_id: string, type: 'route_deviation' | 'speed_anomaly', locationPg: string) => {
  try {
    await query(
      `INSERT INTO anomaly_events (trip_id, type, location) VALUES ($1, $2, ST_GeogFromText($3))`,
      [ride_id, type, locationPg]
    );
    console.log(`[Anomaly] Logged ${type} for ride ${ride_id}`);
  } catch (error) {
    console.error('Failed to log anomaly to database:', error);
  }
};
