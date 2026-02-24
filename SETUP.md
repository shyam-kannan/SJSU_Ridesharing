# LessGo - Setup Instructions (Windows & Mac)

Step-by-step instructions to get the backend and iOS app running on your machine.

> **Windows users:** follow Sections 1–10 below.
> **Mac users:** jump to [Setup for Mac Users](#setup-for-mac-users) near the bottom.

---

## 1. Prerequisites

You need two things installed before starting:

### Node.js v22 (LTS)

Download and install from: https://nodejs.org/en/download

After installing, verify in a new terminal:
```
node --version
```
You should see `v22.x.x`.

### Docker Desktop

Download and install from: https://www.docker.com/products/docker-desktop/

After installing, **restart your computer**.

After restart, open Docker Desktop and wait for it to say "Docker Desktop is running". Then verify in a terminal:
```
docker --version
docker compose version
```

---

## 2. Clone and Install

```
git clone <repo-url>
cd lessgo-backend
```

Install all dependencies (this handles all 8 services via npm workspaces):
```
npm install
```

Build the shared package (required before services can run):
```
cd shared
npm run build
cd ..
```

---

## 3. Verify .env File

Check that `.env` exists in the project root:
```
ls .env
```

**No changes needed for basic setup.** All API keys (Stripe, Google Maps, JWT secret, database credentials) are already configured with development/test values. These are shared test keys for the team.

### Email Notifications Setup (Optional)

LessGo sends real emails for booking confirmations, payment receipts, and trip reminders. Without SMTP configured, the notification endpoints still succeed but log to console only.

**Gmail App Password steps:**
1. Use or create a Gmail account for sending (e.g. `lessgo.sjsu@gmail.com`)
2. Enable 2-Factor Authentication on the account
3. Go to **Google Account → Security → 2-Step Verification → App passwords**
4. Select **Mail**, generate, and copy the 16-character password

**Add to root `.env`:**
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your16charpassword
FROM_EMAIL=LessGo <noreply@lessgo.app>
```

> **Note:** `SMTP_PASS` must be the 16-character app password with no spaces.

---

## 4. Start Infrastructure

Start PostgreSQL (with PostGIS) and Redis in Docker:
```
docker compose up -d
```

Verify both containers are running:
```
docker compose ps
```

You should see two containers with status `running`:
- `lessgo-postgres` (port 5432)
- `lessgo-redis` (port 6379)

---

## 5. Database Setup

Create all database tables:
```
npm run migrate:up
```

You should see output like:
```
> Migrating files: 20260214000001_enable_postgis
> Migrating files: 20260214000002_create_users_table
> ...
```

Load test data:
```
npm run seed
```

The seed creates **50 users** (25 drivers, 25 riders, all verified) and **108 trips** — 54 trips TO SJSU and 54 trips FROM SJSU, covering 10 Bay Area hubs from SF Caltrain (66 km) to Santa Clara (8 km).

---

## 6. Start Services

Open **8 separate terminals**. In each one, navigate to the project root first, then run the command shown.

| Terminal | Command | Service | Port |
|----------|---------|---------|------|
| 1 | `cd services/auth-service && npm run dev` | Auth | 3001 |
| 2 | `cd services/user-service && npm run dev` | User | 3002 |
| 3 | `cd services/trip-service && npm run dev` | Trip | 3003 |
| 4 | `cd services/booking-service && npm run dev` | Booking | 3004 |
| 5 | `cd services/payment-service && npm run dev` | Payment | 3005 |
| 6 | `cd services/notification-service && npm run dev` | Notification | 3006 |
| 7 | `cd services/cost-calculation-service && npm run dev` | Cost Calc | 3009 |
| 8 | `cd services/api-gateway && npm run dev` | API Gateway | 3000 |

Each service should print something like:
```
Auth Service is running
Port: 3001
```

Wait until all 8 terminals show their service running before proceeding.

---

## 7. Run Tests

Open a **9th terminal** and run from the project root:

**Windows (PowerShell):**
```powershell
.\tests\run-all-tests.ps1
```

**Run all tests including gateway E2E:**
```powershell
.\tests\run-all-tests.ps1 -All
```

The test runner will:
1. Check which services are running (pre-flight)
2. Run Auth tests (register, login, verify, token refresh)
3. Run User tests (profile, driver setup, ratings)
4. Run Trip tests (create, search, update, cancel)
5. Run Booking tests (create, confirm, cancel)
6. Run Payment tests (create intent, duplicate rejection)
7. Optionally run API Gateway E2E tests (full flow through port 3000)

You should see mostly green checkmarks.

**Test new iOS features (email, password change, notifications, support):**
```bash
./tests/test-ios-features.sh
```

This tests: change password, device token registration, notification preferences, all 5 email endpoints, and report-issue validation. Expected: **16/16 passed**.

---

## 8. Verify Everything Works

Quick check that the system is healthy:

```
curl http://localhost:3000/health
```

Expected response:
```json
{"status":"success","message":"API Gateway is running"}
```

Try the gateway routing:
```
curl http://localhost:3000/api/trips
```

This should return a list of seeded trips.

---

## 9. Common Issues

### "docker compose not found"
Install Docker Desktop and **restart your computer**. Docker Desktop must be running (check the system tray icon).

### "npm not found" or wrong Node version
Install Node.js v22 from https://nodejs.org and **restart your terminal** (or open a new one).

### "Cannot find module '@lessgo/shared'"
You need to build the shared package first:
```
cd shared
npm run build
cd ..
```

### "Port XXXX already in use"
Another process is using that port. Find and kill it:
```
# Windows PowerShell
netstat -ano | findstr :3001
taskkill /PID <pid> /F

# Mac/Linux
lsof -i :3001
kill -9 <pid>
```

### Services won't start / DB connection error
Make sure Docker containers are running:
```
docker compose ps
```

If they're not running:
```
docker compose up -d
```

### Migration fails with "relation already exists"
The tables already exist. This is fine if you've run migrations before. To start fresh:
```
npm run migrate:down
npm run migrate:up
npm run seed
```

### Seed fails with "duplicate key"
The seed data already exists. To re-seed, drop and recreate:
```
npm run migrate:down
npm run migrate:up
npm run seed
```

### PowerShell says "cannot be loaded because running scripts is disabled"
Run this once in PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 10. Architecture Overview

```
lessgo-backend/
  shared/             Shared types, middleware, DB connection (@lessgo/shared)
  services/
    api-gateway/      Port 3000 - Routes requests to services, JWT validation, rate limiting
    auth-service/     Port 3001 - Register, login, JWT tokens, SJSU ID verification
    user-service/     Port 3002 - User profiles, driver setup, ratings
    trip-service/     Port 3003 - Trip CRUD, geocoding, PostGIS spatial search
    booking-service/  Port 3004 - Bookings, quotes (via Cost Service), payment (via Payment Service)
    payment-service/  Port 3005 - Stripe PaymentIntents, capture, refund
    notification-service/  Port 3006 - Real email (nodemailer/SMTP) + push notification endpoints
    cost-calculation-service/  Port 3009 - Trip cost calculation
  tests/              PowerShell test scripts for all services
  docs/               API documentation
```

**How it fits together:**
- All client requests go through the **API Gateway** (port 3000)
- The gateway validates JWT tokens and routes `/api/auth/*` to Auth Service, `/api/trips/*` to Trip Service, etc.
- Services communicate with each other directly (e.g., Booking Service calls Payment Service and Cost Service)
- All services share one PostgreSQL database (with PostGIS for geospatial queries)
- The `@lessgo/shared` package contains types, middleware, and utilities used by all services

**Test data credentials:**
- Seeded users: `user1@sjsu.edu` through `user50@sjsu.edu`
- Password for all: `Password123`
- 25 drivers, 25 riders, all SJSU-verified
- 108 trips covering 10 Bay Area hubs: SF (66 km), Oakland (58 km), Fremont (24 km), Palo Alto (28 km), and more

---

## Quick Reference

| Action | Command |
|--------|---------|
| Install everything | `npm install` |
| Build shared package | `cd shared && npm run build` |
| Start Docker | `docker compose up -d` |
| Stop Docker | `docker compose down` |
| Run migrations | `npm run migrate:up` |
| Undo migrations | `npm run migrate:down` |
| Seed database | `npm run seed` |
| Run all tests (Windows) | `.\tests\run-all-tests.ps1 -All` |
| Run all tests (Mac) | `./tests/run-all-tests.sh --all` |
| Test iOS features | `./tests/test-ios-features.sh` |
| Check service health | `curl http://localhost:3000/health` |

---

---

## Setup for Mac Users

### Prerequisites (Mac)

- macOS 13+ (Ventura or later recommended)
- **Node.js v22 LTS** — https://nodejs.org/
- **Docker Desktop for Mac** — https://www.docker.com/products/docker-desktop/
- **Xcode 15+** — download from the Mac App Store
- **Git** — pre-installed on macOS (`xcode-select --install` if missing)

---

### 1. Clone Repository

```bash
git clone <repo-url>
cd SJSU_Ridesharing
```

---

### 2. Backend Setup (Mac)

**Install dependencies:**
```bash
# Install all service dependencies via npm workspaces
npm install

# Build the shared package (required before any service can start)
cd shared
npm run build
cd ..
```

**Start infrastructure (PostgreSQL + Redis):**
```bash
docker compose up -d

# Verify both containers are running
docker compose ps
# Should show: lessgo-postgres (5432) and lessgo-redis (6379) — both "running"
```

**Set up the database:**
```bash
# Create all tables
npm run migrate:up

# Load test data (50 users, 100 trips, bookings, ratings)
npm run seed
```

---

### 3. Start Backend Services

#### **Option A: Automated Startup (Recommended) ⚡**

Choose one of these automated methods to start all 8 services at once:

**Method 1: Single Terminal with Concurrently** (All services in one window with color-coded output)
```bash
npm run dev:all
```

**Method 2: Shell Script** (Opens each service in a separate Terminal tab)
```bash
./start-services.sh
```

**Method 3: VS Code Task** (Press `Cmd+Shift+B` or `Cmd+Shift+P` → "Run Task" → "Start All Backend Services")

---

#### **Option B: Manual Startup** (Original Method)

Open **8 separate Terminal tabs** (Cmd+T) and run one command per tab from the project root:

| Tab | Command | Service | Port |
|-----|---------|---------|------|
| 1 | `cd services/api-gateway && npm run dev` | API Gateway | 3000 |
| 2 | `cd services/auth-service && npm run dev` | Auth | 3001 |
| 3 | `cd services/user-service && npm run dev` | User | 3002 |
| 4 | `cd services/trip-service && npm run dev` | Trip | 3003 |
| 5 | `cd services/booking-service && npm run dev` | Booking | 3004 |
| 6 | `cd services/payment-service && npm run dev` | Payment | 3005 |
| 7 | `cd services/notification-service && npm run dev` | Notification | 3006 |
| 8 | `cd services/cost-calculation-service && npm run dev` | Cost Calc | 3009 |

Wait until all 8 tabs show their service running before proceeding.

**Verify the gateway is up:**
```bash
curl http://localhost:3000/health
```
Expected: `{"status":"success","message":"API Gateway is running"}`

---

### 4. Run Backend Tests (Mac)

```bash
cd SJSU_Ridesharing
./tests/run-all-tests.sh --all
```

All services should show ✅ passing tests.

**Test new iOS features:**
```bash
./tests/test-ios-features.sh
```

Expected: **16/16 passed** (change password, device tokens, notification preferences, email endpoints, support).

---

### 5. iOS App Setup (Xcode)

**Open the project:**
1. Launch Xcode
2. **File → Open**
3. Navigate to `SJSU_Ridesharing/LessGo/`
4. Select `LessGo.xcodeproj` → **Open**

**Build and run:**
1. Select **iPhone 15 Pro** simulator from the device dropdown (top toolbar)
2. Press **Cmd+R** (or click ▶ Play)
3. Wait for compilation (~30–60 seconds on first build)
4. The app launches in the iOS Simulator

---

### 6. iOS App Testing

**Basic flow test:**
1. **Login:** `user1@sjsu.edu` / `Password123`
2. **Profile:** Should show "Verified ✅" badge
3. **Search Trips:**
   - Toggle "To SJSU" → should show trips from Bay Area hubs to SJSU
   - Toggle "From SJSU" → should show trips from SJSU to Bay Area
   - Switch to **Map view** → pins at correct locations (origin for To SJSU, destination for From SJSU)
   - Search "San Francisco" → 10+ trips, "Fremont" → 8+ trips
4. **Book a Ride:**
   - Tap any trip → "Book Ride" → confirm → complete payment
   - **Check your email** for booking confirmation and payment receipt

**Account management:**
- **Profile → Change Password:** Current `Password123` → New `NewPass123!` → logout → login with new password
- **Profile → Help & Support:** FAQ (6+ questions), Contact Support (mail composer), Report Issue (form with validation)
- **Profile → About:** App info, mission, team, impact stats

**Map & Search:**
- Map markers update when toggling To/From SJSU
- Tap pin → trip details bottom sheet
- Sort by: All / Leaving Soon / Best Rated / Cheapest

**Common issues:**
- **"Invalid token"**: Logout/login (tokens expire after 15 min)
- **"Verification required"**: Check Profile shows "Verified", refresh app if needed
- **No trips**: Verify all 8 backend services running
- **No email**: Check Gmail spam, verify `SMTP_PASS` in `.env`, check notification-service logs

---

## Test User Credentials

After running `npm run seed`, the database contains:

**50 users:**
- Emails: `user1@sjsu.edu` through `user50@sjsu.edu`
- Password: **`Password123`** (all accounts)
- 25 drivers (with vehicles), 25 riders
- All verified (`sjsu_id_status = 'verified'`)

**108 trips:**
- 54 trips **TO SJSU** from 10 Bay Area hubs
- 54 trips **FROM SJSU** to same hubs
- Locations: SF Caltrain (66 km), Oakland BART (58 km), Fremont BART (24 km), Palo Alto Caltrain (28 km), Milpitas, Santa Clara, Sunnyvale, Mountain View, Cupertino, Berkeley
- Times: Morning rush (7–9 AM) for To SJSU, afternoon/evening (3–7 PM) for From SJSU

### Testing New Registration + Verification

1. In the iOS app, tap **"Sign Up for Free"**
2. Fill in name, email (`yourname@sjsu.edu`), password (`Test123!`), and role
3. Tap **"Create Account"**
4. You'll see a yellow **"Verify your SJSU ID"** banner
5. Tap **"Verify"**
6. **Debug Mode only:** tap **"🧪 USE TEST ID (Debug Mode)"**
7. The ID is processed and **instantly verified** in debug builds
8. Return to Home — the banner disappears and you can now browse and book rides

---

## Project Structure

```
SJSU_Ridesharing/
├── LessGo/                         # iOS Xcode project
│   ├── LessGo.xcodeproj            # Open this in Xcode
│   └── LessGo/                     # Swift source files
│       ├── App/
│       ├── Core/                   # Feature modules (Home, Auth, Trip, Booking...)
│       ├── Models/
│       ├── Services/               # NetworkManager, AuthService, TripService...
│       └── Utils/                  # Constants, theme colors, reusable components
├── services/                       # Backend microservices (Node.js / TypeScript)
│   ├── api-gateway/                # Port 3000 — JWT auth, routing
│   ├── auth-service/               # Port 3001 — register, login, SJSU ID verification
│   ├── user-service/               # Port 3002 — profiles, driver setup, ratings
│   ├── trip-service/               # Port 3003 — trip CRUD, geospatial search
│   ├── booking-service/            # Port 3004 — bookings, payments
│   ├── payment-service/            # Port 3005 — Stripe PaymentIntents
│   ├── notification-service/       # Port 3006 — real email (nodemailer) + push notifications
│   └── cost-calculation-service/   # Port 3009 — fare calculation
├── shared/                         # Shared types and utilities (@lessgo/shared)
├── tests/                          # Backend API test scripts
│   ├── test-auth.sh
│   ├── test-trip.sh
│   ├── test-ios-features.sh        # Email, password change, notifications, support
│   └── run-all-tests.sh
└── SETUP.md                        # This file
```

> **Note:** The `LessGo-iOS` folder is legacy and can be ignored. All iOS code is in `LessGo/` as a proper Xcode project.

---

## Troubleshooting (Mac)

**"docker compose not found"**
Install Docker Desktop for Mac, then restart your Mac. Verify with `docker --version`.

**"npm not found" or wrong Node version**
Install Node.js v22 LTS from https://nodejs.org and restart your terminal. Verify with `node --version`.

**"Cannot find module '@lessgo/shared'"**
Build the shared package first:
```bash
cd shared && npm run build && cd ..
```

**"Port XXXX already in use"**
```bash
lsof -i :3001        # find the process
kill -9 <pid>        # stop it
```

**iOS app shows "Unauthorized" or network errors**
- Ensure all 8 backend services are running in their Terminal tabs
- Check Docker: `docker compose ps` (postgres and redis must be "running")
- The simulator connects via `127.0.0.1:3000` — confirm `NetworkManager.swift` has `baseURL = "http://127.0.0.1:3000/api"`

**Xcode build errors**
Clean the build folder (**Product → Clean Build Folder**, or Cmd+Shift+K), then rebuild with Cmd+R.

**Backend tests fail**
```bash
docker compose up -d        # ensure Docker is running
npm run migrate:up          # re-run migrations if needed
npm run seed                # re-seed test data
```

**Migration fails with "relation already exists"**
```bash
npm run migrate:down
npm run migrate:up
npm run seed
```
