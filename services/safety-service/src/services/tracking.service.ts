// import Redis from 'ioredis';
// import { config } from '../config';
import polyline from '@mapbox/polyline';

// NOTE: Redis functionality has been commented out to allow the service to run without Redis configuration.
// Ride state is now stored in-memory using a Map for development purposes.
// To restore Redis: uncomment the imports above and re-enable all Redis-related code.

// let redisClientInstance: Redis | null = null;
// let redisInitializationPromise: Promise<boolean> | null = null;

// const getOrCreateRedisClient = (): Redis => {
//   if (!redisClientInstance) {
//     redisClientInstance = new Redis(config.redisUrl);
//   }
//   return redisClientInstance;
// };

// const redisClient: Redis = new Proxy({} as Redis, {
//   get(_target, prop, receiver) {
//     const client = getOrCreateRedisClient();
//     const value = Reflect.get(client as unknown as object, prop, receiver);
//     return typeof value === 'function' ? value.bind(client) : value;
//   },
// });

// export const initializeRedis = async () => {
//   const client = getOrCreateRedisClient();
//
//   if (client.status === 'ready') {
//     console.log('✅ Connected to Redis successfully');
//     return true;
//   }
//
//   if (!redisInitializationPromise) {
//     redisInitializationPromise = new Promise<boolean>((resolve, reject) => {
//       client.once('ready', () => {
//         console.log('✅ Connected to Redis successfully');
//         resolve(true);
//       });
//       client.once('error', (err) => {
//         console.error('❌ Redis connection error:', err);
//         redisInitializationPromise = null;
//         reject(err);
//       });
//     });
//   }
//
//   return redisInitializationPromise;
// };

// export const getRedisClient = () => getOrCreateRedisClient();

// In-memory storage for ride state (development only)
export interface GeoPoint {
  lat: number;
  lng: number;
}

export interface RideState {
  ride_id: string;
  planned_route: GeoPoint[];
  // For sliding window of anomalies
  speed_violations_count: number;
}

// In-memory storage for ride states
const rideStates = new Map<string, RideState>();

// Speed violations storage with timestamps
interface SpeedViolationWindow {
  count: number;
  expiresAt: number;
}
const speedViolations = new Map<string, SpeedViolationWindow>();

/**
 * Start tracking a ride, storing its decoded polyline route
 */
export const startTracking = async (ride_id: string, encoded_polyline: string) => {
  const decoded = polyline.decode(encoded_polyline);
  // polyline.decode returns an array of [lat, lng] arrays
  const planned_route: GeoPoint[] = decoded.map((point: number[]) => ({ lat: point[0], lng: point[1] }));

  const state: RideState = {
    ride_id,
    planned_route,
    speed_violations_count: 0
  };

  // Store in-memory (no expiration - relies on stopTracking to clean up)
  rideStates.set(ride_id, state);
  console.log(`[Tracking] Started tracking ride ${ride_id} with ${planned_route.length} route points`);
};

/**
 * Stop tracking a ride
 */
export const stopTracking = async (ride_id: string) => {
  rideStates.delete(ride_id);
  speedViolations.delete(ride_id);
  console.log(`[Tracking] Stopped tracking ride ${ride_id}`);
};

/**
 * Get active ride state
 */
export const getRideState = async (ride_id: string): Promise<RideState | null> => {
  return rideStates.get(ride_id) || null;
};

/**
 * Update ride state
 */
export const updateRideState = async (ride_id: string, state: RideState) => {
  rideStates.set(ride_id, state);
};

/**
 * Get speed violations count for the last N seconds window (sliding window)
 * Simplified in-memory implementation without Redis
 */
export const incrementAndGetSpeedViolations = async (ride_id: string, windowSeconds: number): Promise<number> => {
  const now = Date.now();
  const key = `safety:speed_violations:${ride_id}`;
  const existing = speedViolations.get(key);

  if (!existing || now > existing.expiresAt) {
    // Create new window
    const newViolation = { count: 1, expiresAt: now + (windowSeconds * 1000) };
    speedViolations.set(key, newViolation);
    return 1;
  }

  // Increment existing window
  existing.count++;
  speedViolations.set(key, existing);
  return existing.count;
};

/**
 * Reset speed violations for a ride
 */
export const resetSpeedViolations = async (ride_id: string) => {
  const key = `safety:speed_violations:${ride_id}`;
  speedViolations.delete(key);
};

