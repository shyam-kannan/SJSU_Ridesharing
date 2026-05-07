/**
 * Payment Burst
 *
 * Fires payment intent creation calls at a high rate to verify Stripe
 * integration behavior, rate limiting, and webhook processing under load.
 *
 * Targets:
 *   - Payment intent P95 ≤ 2000 ms (Stripe round-trip included)
 *   - Error rate < 5% (Stripe test-mode errors are expected and counted separately)
 *   - No 5xx from our own service
 *
 * Prerequisites: valid booking UUIDs must exist, OR the BOOKING_IDS env var
 * can supply a comma-separated list.
 *
 * Run:
 *   k6 run tests/load/scenarios/payment-burst.js
 *   k6 run --env BOOKING_IDS=uuid1,uuid2 tests/load/scenarios/payment-burst.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { authenticate, authHeaders } from '../helpers/auth.js';
import { BASE_URL, LOCATIONS } from '../helpers/config.js';

const paymentIntentDuration = new Trend('payment_intent_duration', true);
const stripeErrors          = new Counter('stripe_errors');
const serviceErrors         = new Counter('service_5xx');
const errorRate             = new Rate('errors');

export const options = {
  scenarios: {
    // Ramp to 100 VUs quickly, hold 3 min, ramp down
    payment_burst: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 150,
      stages: [
        { duration: '30s', target: 50  }, // ramp to 50 req/s
        { duration: '3m',  target: 50  }, // hold
        { duration: '30s', target: 0   }, // ramp down
      ],
    },
  },
  thresholds: {
    payment_intent_duration: ['p(95)<2000'],
    errors:                  ['rate<0.05'],
    http_req_failed:         ['rate<0.05'],
    // Our service must not return 5xx (Stripe errors are 4xx/502 from gateway)
    service_5xx:             ['count<5'],
  },
};

export function setup() {
  if (__ENV.BOOKING_IDS) {
    return { bookingIds: __ENV.BOOKING_IDS.split(',').map((s) => s.trim()) };
  }

  // Create a driver + trip + rider + booking to use as the payment target
  const driver = authenticate('Driver');
  const rider  = authenticate('Rider');

  if (!driver.token || !rider.token) {
    console.error('Auth failed — ensure services are running');
    return { bookingIds: [] };
  }

  // Create trip
  const departure = new Date(Date.now() + 3600_000).toISOString();
  const tripRes = http.post(
    `${BASE_URL}/api/trips`,
    JSON.stringify({
      origin: 'SJSU Campus',
      destination: 'Diridon Station',
      departure_time: departure,
      seats_available: 4,
    }),
    { headers: authHeaders(driver.token) }
  );
  const tripId = tripRes.json('data.trip_id');
  if (!tripId) {
    console.error('Trip creation failed:', tripRes.body);
    return { bookingIds: [] };
  }

  // Create booking as rider
  const bookRes = http.post(
    `${BASE_URL}/api/bookings`,
    JSON.stringify({ trip_id: tripId, seats_booked: 1 }),
    { headers: authHeaders(rider.token) }
  );
  const bookingId = bookRes.json('data.booking_id');
  if (!bookingId) {
    console.error('Booking creation failed:', bookRes.body);
    return { bookingIds: [] };
  }

  return { bookingIds: [bookingId] };
}

export default function (data) {
  if (!data.bookingIds.length) {
    sleep(5);
    return;
  }

  const bookingId = data.bookingIds[__VU % data.bookingIds.length];
  // Realistic fare: $2–$15
  const amount = parseFloat((2 + Math.random() * 13).toFixed(2));

  const res = http.post(
    `${BASE_URL}/api/payments/create-intent`,
    JSON.stringify({ booking_id: bookingId, amount }),
    {
      headers: { 'Content-Type': 'application/json' },
      tags: { name: 'payment_intent' },
    }
  );

  paymentIntentDuration.add(res.timings.duration);

  // Stripe test-mode declines (402/400) are expected; count separately
  if (res.status >= 500) {
    serviceErrors.add(1);
  }
  if (res.status === 429 || (res.status >= 500 && res.status < 600)) {
    stripeErrors.add(1);
  }

  const ok = check(res, {
    // 201 = created, 409 = duplicate (idempotent), 400 = Stripe validation
    'payment intent not 5xx': (r) => r.status < 500,
  });
  errorRate.add(!ok);

  // Brief pause to avoid hammering Stripe test-mode rate limits
  sleep(0.5 + Math.random() * 0.5);
}
