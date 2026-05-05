# LessGo — Backend Developer Guide

> **This is the authoritative run-book.** For iOS setup see `SETUP.md`. For Kubernetes/GKE deployment see `README.md`.

---

## Quick Start (TL;DR)

```bash
# 1 — first time only
npm install && cd shared && npm run build && cd ..
npm run bootstrap:db -- --fresh   # migrations + seed 50 users / 108 trips

# 2 — every session
docker compose up -d              # start Redis
npm run dev:all                   # all 8 Node services in one window (colour-coded)

# — or use the script —
./scripts/dev.sh start            # background mode with health check
```

Health check: `curl http://localhost:3000/health`

---

## Prerequisites

| Tool | Required version | Install |
|------|-----------------|---------|
| Node.js | v22 LTS | https://nodejs.org |
| Docker Desktop | any current | https://www.docker.com/products/docker-desktop |
| Python | 3.10 – 3.11 | https://python.org *(optional — only for ML/routing services)* |
| Git | any | pre-installed on macOS |

Verify before continuing:
```bash
node --version   # v22.x.x
docker --version
python3 --version
```

---

## First-Time Setup

```bash
# 1. Install all workspace dependencies (shared + all services)
npm install

# 2. Build the shared package — required before any service can import @lessgo/shared
cd shared && npm run build && cd ..

# 3. Copy environment file (only needed if .env is missing)
cp .env.example .env

# 4. Start Redis
docker compose up -d
docker compose ps   # should show lessgo-redis → running

# 5. Run database migrations
npm run bootstrap:db

# 6. (Optional) Seed demo data — 50 users + 108 trips — safe to repeat on empty DB
npm run bootstrap:db -- --fresh
```

> PostgreSQL is hosted on **Supabase** — no local Postgres container is needed.
> The `.env` file already has working development credentials shared by the team.

---

## Daily Development Workflow

### Option A — single terminal (recommended)

```bash
docker compose up -d   # Redis must be up first
npm run dev:all        # all 8 Node services, colour-coded output
```

Press `Ctrl+C` to stop everything.

### Option B — managed background script

```bash
./scripts/dev.sh start    # start all services in background, then health-check
./scripts/dev.sh status   # print health of every service
./scripts/dev.sh stop     # kill all service processes
./scripts/dev.sh restart  # stop → start
```

Logs are written to `/tmp/*.log` (`auth.log`, `trip.log`, etc.).

### Option C — per-service (debugging a single service)

```bash
# Start just one service
npm run dev:gateway
npm run dev:auth
npm run dev:trip
# etc.

# Or cd directly
cd services/trip-service && npm run dev
```

### Stop everything

```bash
# Stop services started by dev:all / the script
pkill -f ts-node-dev
pkill -f "node.*dist/server"

# Stop Redis
docker compose down
```

---

## Service Catalog

| Service | Port | Stack | Role |
|---------|------|-------|------|
| API Gateway | 3000 | Node/Express | JWT validation, request routing, rate limiting |
| Auth Service | 3001 | Node/TS | Register, login, SJSU ID verification, JWT |
| User Service | 3002 | Node/TS | Profiles, driver setup, ratings, device tokens |
| Trip Service | 3003 | Node/TS | Trip CRUD, PostGIS search, **matching pipeline** |
| Booking Service | 3004 | Node/TS | Bookings, fare quotes, payment orchestration |
| Payment Service | 3005 | Node/TS | Stripe PaymentIntents, capture, refund |
| Notification Service | 3006 | Node/TS | SMTP email, push notifications |
| Cost Calculation | 3009 | Node/TS | Fare calculation |
| Embedding Service | 3010 | Python/FastAPI | RShareForm ML trajectory matching |
| Routing Service | 8002 | Python/FastAPI | Google Maps distance/route calculation |
| Grouping Service | 8000 | Python/FastAPI | Carpool group optimisation |
| Safety Service | 8005 | Node/TS | Real-time location anomaly detection |
| Redis | 6379 | Docker | Session cache |

> `npm run dev:all` starts the **8 Node services** (ports 3000–3009).
> Python services (3010, 8000–8005) must be started separately — see [Python Services](#python-services-optional).

---

## Matching Architecture — Two-Way Marketplace

The Trip Service runs a **three-stage pipeline** (PostGIS → RShareForm embeddings → He et al. Scost) in two directions simultaneously.

### Flow diagram

```
Driver posts trip  ──→  matchDriver()  ──→  notifies driver if a pooled rider matches
                                                       ↓
                                              Driver accepts / declines

Rider requests ride ──→  matchRider()  ──→  returns up to 5 ranked CandidateDrivers
                                                       ↓
                                 Rider selects one  ──→  selectDriverForRider()
                                    OR skips         ──→  stays in pool (polling)
                                                       ↓
                                              Driver accepts / declines
```

### Stage details

| Stage | Rider-Initiated | Driver-Initiated |
|-------|----------------|-----------------|
| **1 PostGIS** | Finds driver trips within 5 000 m of rider origin (or 1 500 m of route line) and ±30 min | Finds pending rider requests within same proximity of driver's trip |
| **2 Embeddings** | Calls `/match` on Embedding Service (RShareForm, Tang et al. 2020) | Maps riders to CandidateTrip shape; calls same embedding endpoint |
| **3 Scost** | Scores each candidate (He et al. eq 9); returns **top 5** sorted ascending | Picks the single rider with lowest Scost; creates `pending_match` |

### Matching endpoints

| Method | Path | Who calls it | What it does |
|--------|------|-------------|--------------|
| `POST` | `/api/trips/request` | Rider | Submit ride request; immediately returns `available_drivers[]` |
| `GET` | `/api/trips/request/:id` | Rider | Poll request status (`pending` → `matched` → `expired`) |
| `POST` | `/api/trips/request/:id/select-driver` | Rider | Select a driver from the ranked list; sends driver a push notification |
| `POST` | `/api/trips/:id/accept-match` | Driver | Accept an incoming match |
| `POST` | `/api/trips/:id/decline-match` | Driver | Decline; system retries with the next best candidate |

### `POST /api/trips/request` — response shape

```jsonc
{
  "status": "success",
  "message": "Ride request submitted. Select a driver below, or your request will remain pooled.",
  "data": {
    "request_id": "uuid",
    "status": "pending",
    "created_at": "2026-05-05T12:00:00Z",
    "available_drivers": [           // [] when no immediate candidates
      {
        "trip_id": "uuid",           // use as trip_id in select-driver call
        "driver_id": "uuid",
        "origin_lat": 37.335,
        "origin_lng": -121.881,
        "destination_lat": 37.338,
        "destination_lng": -121.886,
        "departure_time": "2026-05-05T12:30:00Z",
        "distance_to_rider_m": 320,  // walking distance to driver pickup
        "seats_available": 2,
        "route_score": 0.8           // >0 = driver frequently drives this corridor
      }
    ]
  }
}
```

### `POST /api/trips/request/:id/select-driver` — request body

```json
{ "trip_id": "uuid", "driver_id": "uuid" }
```

### Driver-initiated pooling — trigger

When a driver calls `POST /api/trips` to create a new trip, `matchDriver(trip_id)` fires in the background (`setImmediate`). If a matching pending rider request is found, the driver receives a push notification immediately — no rider action required.

---

## Database

### Migrations

```bash
npm run migrate:status    # list applied migrations
npm run migrate:up        # apply pending migrations
npm run migrate:down      # roll back one migration
npm run migrate:create    # scaffold a new migration file
```

### Full bootstrap

```bash
npm run bootstrap:db               # migrations only
npm run bootstrap:db -- --fresh    # migrations + seed demo data
```

### Demo data (after --fresh)

| Entity | Count | Details |
|--------|-------|---------|
| Users | 50 | 25 drivers, 25 riders — all SJSU-verified |
| Trips | 108 | 54 To SJSU + 54 From SJSU across 10 Bay Area hubs |
| Credentials | — | `user1@sjsu.edu` … `user50@sjsu.edu` / `Password123` |

---

## Testing

### Quick smoke test

```bash
curl http://localhost:3000/health
# → {"status":"success","message":"API Gateway is running"}
```

### Full integration suite (Mac/Linux)

```bash
./tests/run-all-tests.sh --all
```

### Individual service tests

```bash
bash tests/test-auth.sh
bash tests/test-trip.sh
bash tests/test-booking.sh
bash tests/test-payment.sh
bash tests/test-user.sh
bash tests/test-ios-features.sh   # email, password change, notifications — expected 16/16
```

### Matching pipeline test

```bash
# 1. Register a rider and get a token
TOKEN=$(curl -s -X POST http://localhost:3001/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"user26@sjsu.edu","password":"Password123"}' \
  | jq -r '.data.access_token')

# 2. Submit a ride request — response now includes available_drivers[]
curl -s -X POST http://localhost:3000/api/trips/request \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "origin": "Milpitas BART",
    "destination": "San Jose State University",
    "origin_lat": 37.4282, "origin_lng": -121.9057,
    "destination_lat": 37.3352, "destination_lng": -121.8811,
    "departure_time": "2026-05-06T08:00:00Z"
  }' | jq '.data | {request_id, available_drivers: (.available_drivers | length)}'
```

### Gateway smoke (prod URL)

```bash
npm run test:gateway:smoke:prod
```

### Unit tests

```bash
npm run test:unit
```

---

## Python Services (Optional)

The ML and routing services are independent FastAPI apps. Start them only when developing features that use embeddings, route optimisation, or carpool grouping.

```bash
# Install Python dependencies (once per service)
pip install -r services/embedding-service/requirements.txt
pip install -r services/routing-service/requirements.txt
pip install -r services/grouping-service/requirements.txt

# Start each in its own terminal
cd services/embedding-service && uvicorn app.main:app --port 3010 --reload
cd services/routing-service   && uvicorn app.main:app --port 8002 --reload
cd services/grouping-service  && uvicorn app.main:app --port 8000 --reload
```

The Embedding Service falls back gracefully when no trained model exists — it returns `model_used: false` and the matching pipeline uses PostGIS distance order instead.

---

## Environment Variables

Key variables in `.env` (team dev values pre-configured):

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | Supabase PostgreSQL connection string |
| `REDIS_URL` | Redis connection (`redis://localhost:6379`) |
| `JWT_SECRET` | Token signing secret |
| `GOOGLE_MAPS_API_KEY` | Used by Trip Service (geocoding) and Routing Service |
| `STRIPE_SECRET_KEY` | Stripe test key (`sk_test_...`) |
| `EMBEDDING_SERVICE_URL` | `http://127.0.0.1:3010` |
| `NOTIFICATION_SERVICE_URL` | `http://127.0.0.1:3006` |
| `SMTP_HOST / SMTP_USER / SMTP_PASS` | Gmail App Password for real emails |

For local iOS testing, set this Xcode scheme env var:
```
LESSGO_API_BASE_URL=http://127.0.0.1:3000/api
```

---

## Troubleshooting

### "Cannot find module '@lessgo/shared'"
```bash
cd shared && npm run build && cd ..
```

### "Port XXXX already in use"
```bash
lsof -i :3003        # find the PID
kill -9 <pid>
```

Or stop everything at once:
```bash
./scripts/dev.sh stop
```

### Service won't start — DB connection error
```bash
docker compose ps          # redis must show "running"
docker compose up -d       # start it if not running
cat .env | grep DATABASE   # verify DATABASE_URL is set
```

### Migration fails with "relation already exists"
Tables are already there — safe to ignore. Run `npm run migrate:status` to confirm all migrations are applied.

### Matching returns empty `available_drivers`
- Confirm seed data is loaded: `npm run bootstrap:db -- --fresh`
- Confirm the deparure_time in your request is within ±30 min of a seeded trip
- Check trip-service logs for `[matching] No candidates found`

### Embedding service not available
The pipeline degrades gracefully — logs `Embedding service unavailable, falling back to PostGIS ranking`. Start the embedding service to enable ML ranking.

---

## Port Reference

```
3000  API Gateway      (all client traffic enters here)
3001  Auth Service
3002  User Service
3003  Trip Service     (matching pipeline lives here)
3004  Booking Service
3005  Payment Service
3006  Notification Service
3009  Cost Calculation Service
3010  Embedding Service (Python — optional)
6379  Redis
8000  Grouping Service  (Python — optional)
8002  Routing Service   (Python — optional)
8005  Safety Service    (optional)
```
