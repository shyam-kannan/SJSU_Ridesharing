/**
 * Morning Commute Spike
 *
 * Simulates hundreds of concurrent riders searching for trips and creating
 * bookings during a peak commute window.
 *
 * Targets:
 *   - Trip discovery P95 ≤ 500 ms
 *   - Booking confirmation P95 ≤ 2000 ms
 *   - Error rate < 5%
 *
 * Run:
 *   k6 run tests/load/scenarios/morning-commute-spike.js
 *   k6 run --env BASE_URL=http://<host>:3000 tests/load/scenarios/morning-commute-spike.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate } from 'k6/metrics';
import { authenticate, authHeaders } from '../helpers/auth.js';
import { BASE_URL, LOCATIONS } from '../helpers/config.js';

// Custom metrics
const tripSearchDuration = new Trend('trip_search_duration', true);
const bookingDuration    = new Trend('booking_duration', true);
const errorRate          = new Rate('errors');

export const options = {
  scenarios: {
    // Ramp up to 200 VUs over 2 min, hold 3 min, ramp down 1 min
    morning_spike: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 200 },
        { duration: '3m', target: 200 },
        { duration: '1m', target: 0 },
      ],
    },
  },
  thresholds: {
    trip_search_duration: ['p(95)<500'],
    booking_duration:     ['p(95)<2000'],
    errors:               ['rate<0.05'],
    http_req_failed:      ['rate<0.05'],
  },
};

// setup() runs once; returns shared auth tokens for VUs to reuse
export function setup() {
  // Pre-create a small pool of rider accounts to avoid hammering /register
  const pool = [];
  for (let i = 0; i < 10; i++) {
    pool.push(authenticate('Rider'));
  }
  return { pool };
}

export default function (data) {
  // Each VU picks a token from the pool
  const account = data.pool[__VU % data.pool.length];
  const headers = authHeaders(account.token);

  // Pick random origin/destination pair
  const origins = [LOCATIONS.sjsu, LOCATIONS.milpitas, LOCATIONS.diridon];
  const dests   = [LOCATIONS.downtown, LOCATIONS.santana_row, LOCATIONS.sjsu];
  const origin  = origins[Math.floor(Math.random() * origins.length)];
  const dest    = dests[Math.floor(Math.random() * dests.length)];

  // 1. Search for trips (trip discovery latency)
  const departure = new Date(Date.now() + 3600_000).toISOString();
  const searchRes = http.get(
    `${BASE_URL}/api/trips/search?origin_lat=${origin.lat}&origin_lng=${origin.lng}` +
    `&destination_lat=${dest.lat}&destination_lng=${dest.lng}&departure_time=${departure}`,
    { headers, tags: { name: 'trip_search' } }
  );

  tripSearchDuration.add(searchRes.timings.duration);
  const searchOk = check(searchRes, {
    'search 200': (r) => r.status === 200,
  });
  errorRate.add(!searchOk);

  // 2. Also hit the list endpoint (simulates app home screen)
  const listRes = http.get(`${BASE_URL}/api/trips`, { headers, tags: { name: 'trip_list' } });
  check(listRes, { 'list 200': (r) => r.status === 200 });

  // 3. Attempt a booking if trips were found
  const trips = searchRes.json('data');
  if (Array.isArray(trips) && trips.length > 0) {
    const trip = trips[0];
    const bookStart = Date.now();
    const bookRes = http.post(
      `${BASE_URL}/api/bookings`,
      JSON.stringify({ trip_id: trip.trip_id, seats_booked: 1 }),
      { headers, tags: { name: 'booking_create' } }
    );
    bookingDuration.add(Date.now() - bookStart);

    const bookOk = check(bookRes, {
      'booking 201/200/409': (r) => [200, 201, 409].includes(r.status),
    });
    errorRate.add(!bookOk);
  }

  sleep(Math.random() * 2 + 1); // 1–3 s think time
}
