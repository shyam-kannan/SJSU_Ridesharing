/**
 * Concurrent Active Trips
 *
 * Simulates many drivers sending frequent location updates while riders
 * poll those locations — stressing the trip service, safety checks, and Redis.
 *
 * Targets:
 *   - Location update P95 ≤ 500 ms
 *   - Location read   P95 ≤ 300 ms
 *   - Error rate < 1%
 *
 * Prerequisites: at least one active trip must exist in the DB, OR the
 * TRIP_IDS env var can supply a comma-separated list of known trip UUIDs.
 *
 * Run:
 *   k6 run tests/load/scenarios/concurrent-active-trips.js
 *   k6 run --env TRIP_IDS=uuid1,uuid2 tests/load/scenarios/concurrent-active-trips.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { authenticate, authHeaders } from '../helpers/auth.js';
import { BASE_URL, LOCATIONS } from '../helpers/config.js';

const locationUpdateDuration = new Trend('location_update_duration', true);
const locationReadDuration   = new Trend('location_read_duration', true);
const errorRate              = new Rate('errors');

export const options = {
  scenarios: {
    // Drivers: 50 VUs sending location updates every ~4 s
    drivers: {
      executor: 'constant-vus',
      vus: 50,
      duration: '5m',
      exec: 'driverLoop',
    },
    // Riders: 150 VUs polling location every ~3 s
    riders: {
      executor: 'constant-vus',
      vus: 150,
      duration: '5m',
      exec: 'riderLoop',
    },
  },
  thresholds: {
    location_update_duration: ['p(95)<500'],
    location_read_duration:   ['p(95)<300'],
    errors:                   ['rate<0.01'],
    http_req_failed:          ['rate<0.01'],
  },
};

// Jitter around a base coordinate to simulate movement
function jitter(coord, delta = 0.005) {
  return coord + (Math.random() - 0.5) * delta;
}

export function setup() {
  // Seed trip IDs from env or create a driver + trip for the test
  if (__ENV.TRIP_IDS) {
    const tripIds = __ENV.TRIP_IDS.split(',').map((s) => s.trim());
    const driver = authenticate('Driver');
    return { tripIds, driverToken: driver.token };
  }

  // Create one driver and one trip to use across all VUs
  const driver = authenticate('Driver');
  if (!driver.token) {
    console.error('Driver auth failed — ensure the service is running');
    return { tripIds: [], driverToken: null };
  }

  const departure = new Date(Date.now() + 1800_000).toISOString();
  const tripRes = http.post(
    `${BASE_URL}/api/trips`,
    JSON.stringify({
      origin: 'SJSU Campus',
      destination: 'Downtown San Jose',
      departure_time: departure,
      seats_available: 3,
    }),
    { headers: authHeaders(driver.token) }
  );

  const tripId = tripRes.json('data.trip_id');
  return {
    tripIds: tripId ? [tripId] : [],
    driverToken: driver.token,
  };
}

export function driverLoop(data) {
  if (!data.tripIds.length || !data.driverToken) {
    sleep(5);
    return;
  }

  const tripId  = data.tripIds[__VU % data.tripIds.length];
  const headers = authHeaders(data.driverToken);

  // Simulate GPS update from a moving driver near SJSU
  const res = http.post(
    `${BASE_URL}/api/trips/${tripId}/location`,
    JSON.stringify({
      latitude:  jitter(LOCATIONS.sjsu.lat),
      longitude: jitter(LOCATIONS.sjsu.lng),
      heading:   Math.random() * 360,
      speed:     20 + Math.random() * 40, // 20–60 km/h
    }),
    { headers, tags: { name: 'location_update' } }
  );

  locationUpdateDuration.add(res.timings.duration);
  const ok = check(res, { 'location update 200/201': (r) => r.status === 200 || r.status === 201 });
  errorRate.add(!ok);

  sleep(3 + Math.random() * 2); // update every ~3–5 s
}

export function riderLoop(data) {
  if (!data.tripIds.length) {
    sleep(5);
    return;
  }

  const tripId = data.tripIds[__VU % data.tripIds.length];

  const res = http.get(
    `${BASE_URL}/api/trips/${tripId}/location`,
    { tags: { name: 'location_read' } }
  );

  locationReadDuration.add(res.timings.duration);
  const ok = check(res, { 'location read 200/404': (r) => r.status === 200 || r.status === 404 });
  errorRate.add(!ok);

  sleep(2 + Math.random() * 2); // poll every ~2–4 s
}

// Default export required by k6 even when using named executors
export default function () {}
