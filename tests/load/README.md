# LessGo Load Tests (k6)

Three k6 scenarios covering the planned load testing areas.

## Prerequisites

Install k6: https://k6.io/docs/get-started/installation/

```bash
# macOS
brew install k6
```

All services must be running. The API Gateway is exposed at `http://136.109.119.177:80` (default). All other services communicate internally and are not directly reachable.

## Scenarios

| Script | Scenario | VUs / Rate | Duration |
|--------|----------|-----------|----------|
| `morning-commute-spike.js` | Riders searching + booking during peak commute | 0 → 200 VUs | 6 min |
| `concurrent-active-trips.js` | Drivers sending location updates + riders polling | 50 drivers + 150 riders | 5 min |
| `payment-burst.js` | High-rate payment intent creation | 0 → 50 req/s | ~4 min |

## Performance Targets

| Operation | Metric | Target |
|-----------|--------|--------|
| Trip discovery | P95 latency | ≤ 500 ms |
| Location read | P95 latency | ≤ 300 ms |
| Booking confirmation | P95 latency | ≤ 2000 ms |
| Payment intent | P95 latency | ≤ 2000 ms |
| Error rate | All scenarios | < 5% |

## Running

```bash
# Individual scenarios (targets 136.109.119.177:80 by default)
npm run test:load:commute
npm run test:load:trips
npm run test:load:payments

# All three in sequence
npm run test:load:all

# Override the gateway URL if needed
k6 run --env BASE_URL=http://localhost:3000 tests/load/scenarios/morning-commute-spike.js

# Inject pre-existing IDs to skip setup() data creation
k6 run --env TRIP_IDS=uuid1,uuid2 tests/load/scenarios/concurrent-active-trips.js
k6 run --env BOOKING_IDS=uuid1,uuid2 tests/load/scenarios/payment-burst.js
```

## File Structure

```
tests/load/
├── helpers/
│   ├── config.js   # BASE_URL, thresholds, SJSU-area coordinates
│   └── auth.js     # authenticate() + authHeaders() helpers
└── scenarios/
    ├── morning-commute-spike.js
    ├── concurrent-active-trips.js
    └── payment-burst.js
```
