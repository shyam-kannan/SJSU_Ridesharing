import Redis from 'ioredis';
import { config } from '../config';
import polyline from '@mapbox/polyline';

let redisClientInstance: Redis | null = null;
let redisInitializationPromise: Promise<boolean> | null = null;

const getOrCreateRedisClient = (): Redis => {
  if (!redisClientInstance) {
    redisClientInstance = new Redis(config.redisUrl);
  }

  return redisClientInstance;
};

const redisClient: Redis = new Proxy({} as Redis, {
  get(_target, prop, receiver) {
    const client = getOrCreateRedisClient();
    const value = Reflect.get(client as unknown as object, prop, receiver);
    return typeof value === 'function' ? value.bind(client) : value;
  },
});

export const initializeRedis = async () => {
  const client = getOrCreateRedisClient();

  if (client.status === 'ready') {
    console.log('✅ Connected to Redis successfully');
    return true;
  }

  if (!redisInitializationPromise) {
    redisInitializationPromise = new Promise<boolean>((resolve, reject) => {
      client.once('ready', () => {
        console.log('✅ Connected to Redis successfully');
        resolve(true);
      });
      client.once('error', (err) => {
        console.error('❌ Redis connection error:', err);
        redisInitializationPromise = null;
        reject(err);
      });
    });
  }

  return redisInitializationPromise;
};

export const getRedisClient = () => getOrCreateRedisClient();

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

// Prefix for Redis keys
const RIDE_KEY_PREFIX = 'safety:ride:';

/**
 * Start tracking a ride, storing its decoded polyline route
 */
export const startTracking = async (ride_id: string, encoded_polyline: string) => {
  const decoded = polyline.decode(encoded_polyline);
  // polyline.decode returns an array of [lat, lng] arrays
  const planned_route: GeoPoint[] = decoded.map(([lat, lng]) => ({ lat, lng }));

  const state: RideState = {
    ride_id,
    planned_route,
    speed_violations_count: 0
  };

  // Store in Redis (expires in 24 hours to prevent memory leaks)
  await redisClient.setex(`${RIDE_KEY_PREFIX}${ride_id}`, 86400, JSON.stringify(state));
};

/**
 * Stop tracking a ride
 */
export const stopTracking = async (ride_id: string) => {
  await redisClient.del(`${RIDE_KEY_PREFIX}${ride_id}`);
};

/**
 * Get active ride state
 */
export const getRideState = async (ride_id: string): Promise<RideState | null> => {
  const data = await redisClient.get(`${RIDE_KEY_PREFIX}${ride_id}`);
  if (!data) return null;
  return JSON.parse(data) as RideState;
};

/**
 * Update ride state
 */
export const updateRideState = async (ride_id: string, state: RideState) => {
  await redisClient.setex(`${RIDE_KEY_PREFIX}${ride_id}`, 86400, JSON.stringify(state));
};

/**
 * Get speed violations count for the last N seconds window (sliding window)
 * We use an atomic INCR with expiration for simplicity. If a speed violation occurs, we increment a counter.
 * The counter expires after the window seconds.
 */
export const incrementAndGetSpeedViolations = async (ride_id: string, windowSeconds: number): Promise<number> => {
  const key = `safety:speed_violations:${ride_id}`;
  const multi = redisClient.multi();
  
  multi.incr(key);
  // Only set TTL if we just created it or it's about to expire?
  // Actually, we can just let it expire if no more violations happen.
  // Wait, INCR on a key that doesn't exist creates it with TTL -1. we need to set EXPIRE.
  
  // A simpler way: we just set expire every time. It resets the window of the "sustained" speeding.
  // So if they keep speeding, the key survives.
  multi.expire(key, windowSeconds);
  
  const results = await multi.exec();
  if (results && results[0] && !results[0][0]) {
    return results[0][1] as number; // Return the incr result
  }
  return 1;
};

export const resetSpeedViolations = async (ride_id: string) => {
  const key = `safety:speed_violations:${ride_id}`;
  await redisClient.del(key);
};
