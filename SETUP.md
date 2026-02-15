# LessGo Backend - Complete Setup Guide

## 🎉 Implementation Complete!

The LessGo carpooling platform backend has been fully implemented with:
- **10 Microservices** (7 Node.js/TypeScript, 3 Python/FastAPI)
- **Complete Authentication** with JWT and SJSU ID verification
- **Geospatial Trip Search** using PostGIS
- **Payment Integration** with Stripe
- **API Gateway** with rate limiting and JWT validation
- **Comprehensive Seed Data** for testing

---

## 📦 What's Been Built

### Priority 1: Foundation ✅
- ✅ PostgreSQL database with 7 complete migrations
- ✅ PostGIS extension for geospatial queries
- ✅ Shared middleware (auth, error handling, logging, CORS)
- ✅ Shared utilities and TypeScript types
- ✅ Auth Service (full implementation)

### Priority 2: Core Services ✅
- ✅ User Service (profile management, driver setup, ratings)
- ✅ Trip Service (geocoding, geospatial search, CRUD)
- ✅ Booking Service (quote generation, payment integration, ratings)
- ✅ Payment Service (Stripe integration, refunds)

### Priority 3: Optimization Services ✅
- ✅ Cost Calculation Service (simple placeholder with ML interface)
- ✅ Grouping Service (Python - simple distance-based with ML interface)
- ✅ Routing Service (Python - full Google Maps + Redis caching)

### Priority 4: Support Services ✅
- ✅ Notification Service (email/push stubs)
- ✅ API Gateway (complete with routing, JWT, rate limiting)
- ✅ Seed Script (50 users, 100 trips, SJSU area data)
- ✅ API Documentation ([docs/api/endpoints.md](docs/api/endpoints.md))

---

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Python 3.10+
- PostgreSQL 15+ with PostGIS
- Redis 7+
- Docker & Docker Compose (recommended)

### 1. Start Infrastructure
```bash
docker-compose up -d
```

This starts:
- PostgreSQL with PostGIS (port 5432)
- Redis (port 6379)

### 2. Install Root Dependencies
```bash
npm install
```

### 3. Configure Environment
Copy `.env.example` to `.env` and update:
```bash
cp .env.example .env
```

Required configuration:
- `JWT_SECRET` - Set a secure secret
- `GOOGLE_MAPS_API_KEY` - Your Google Maps API key
- `STRIPE_SECRET_KEY` - Your Stripe test key (sk_test_...)

### 4. Run Database Migrations
```bash
npm run migrate:up
```

This creates all tables with PostGIS support.

### 5. Seed Test Data
```bash
npm run seed
```

This creates:
- 50 users (user1@sjsu.edu through user50@sjsu.edu, password: Password123)
- 100 trips in SJSU area
- 50 bookings with quotes and payments
- Ratings for completed bookings

---

## 🏃 Running Services

### Option 1: Run All Services Individually

**Node.js Services:**
```bash
# Terminal 1: Auth Service (port 3001)
cd services/auth-service && npm install && npm run dev

# Terminal 2: User Service (port 3002)
cd services/user-service && npm install && npm run dev

# Terminal 3: Trip Service (port 3003)
cd services/trip-service && npm install && npm run dev

# Terminal 4: Booking Service (port 3004)
cd services/booking-service && npm install && npm run dev

# Terminal 5: Payment Service (port 3005)
cd services/payment-service && npm install && npm run dev

# Terminal 6: Notification Service (port 3006)
cd services/notification-service && npm install && npm run dev

# Terminal 7: Cost Calculation Service (port 3009)
cd services/cost-calculation-service && npm install && npm run dev

# Terminal 8: API Gateway (port 3000)
cd services/api-gateway && npm install && npm run dev
```

**Python Services:**
```bash
# Terminal 9: Grouping Service (port 8001)
cd services/grouping-service
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app/main.py

# Terminal 10: Routing Service (port 8002)
cd services/routing-service
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app/main.py
```

### Option 2: Use Root npm Scripts
```bash
npm run dev:auth      # Start Auth Service
npm run dev:user      # Start User Service
npm run dev:trip      # Start Trip Service
npm run dev:booking   # Start Booking Service
npm run dev:payment   # Start Payment Service
npm run dev:gateway   # Start API Gateway
# ... etc
```

---

## 🧪 Testing the API

### Using the API Gateway (Recommended)
All requests go through: `http://localhost:3000/api`

### Example Workflow

**1. Register a User**
```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@sjsu.edu",
    "password": "Password123",
    "role": "Driver"
  }'
```

**2. Login**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user1@sjsu.edu",
    "password": "Password123"
  }'
```

Save the `accessToken` from the response.

**3. Search for Trips**
```bash
curl -X GET "http://localhost:3000/api/trips/search?origin_lat=37.3352&origin_lng=-122.8811&radius_meters=10000" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**4. Create a Booking**
```bash
curl -X POST http://localhost:3000/api/bookings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "trip_id": "TRIP_UUID_FROM_SEARCH",
    "seats_booked": 1
  }'
```

**5. Confirm Booking (Process Payment)**
```bash
curl -X PUT http://localhost:3000/api/bookings/BOOKING_ID/confirm \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## 📚 API Documentation

Complete API documentation: [docs/api/endpoints.md](docs/api/endpoints.md)

All endpoints, request/response formats, and authentication requirements are documented there.

---

## 🏗️ Architecture Overview

```
┌─────────────────┐
│  API Gateway    │  Port 3000 - Entry point
│  (Rate Limit,   │
│   JWT Validate) │
└────────┬────────┘
         │
         ├─────────────────────────────────────┐
         │                                     │
    ┌────▼─────┐  ┌──────────┐  ┌───────────┐
    │   Auth   │  │   User   │  │   Trip    │
    │ Service  │  │ Service  │  │  Service  │
    │  (3001)  │  │  (3002)  │  │  (3003)   │
    └──────────┘  └──────────┘  └───────────┘

    ┌──────────┐  ┌──────────┐  ┌───────────┐
    │ Booking  │  │ Payment  │  │   Notif   │
    │ Service  │  │ Service  │  │  Service  │
    │  (3004)  │  │  (3005)  │  │  (3006)   │
    └──────────┘  └──────────┘  └───────────┘

    ┌──────────┐  ┌──────────┐  ┌───────────┐
    │ Grouping │  │ Routing  │  │   Cost    │
    │ (Python) │  │ (Python) │  │  Calc     │
    │  (8001)  │  │  (8002)  │  │  (3009)   │
    └──────────┘  └──────────┘  └───────────┘
                        │
        ┌───────────────┴─────────────┐
        │                             │
    ┌───▼──────┐               ┌──────▼──┐
    │PostgreSQL│               │  Redis  │
    │ PostGIS  │               │         │
    └──────────┘               └─────────┘
```

---

## 🔑 Key Features

### Authentication & Security
- ✅ bcrypt password hashing
- ✅ JWT tokens (access: 15min, refresh: 7 days)
- ✅ SJSU ID verification with image upload
- ✅ Role-based access control (Driver/Rider)
- ✅ Rate limiting (100 requests per 15 minutes)

### Geospatial Capabilities
- ✅ PostGIS for location-based queries
- ✅ Google Maps geocoding (address → coordinates)
- ✅ Radius-based trip search (ST_DWithin queries)
- ✅ Distance calculations using geography type

### Payment Processing
- ✅ Stripe PaymentIntent creation
- ✅ Payment capture and confirmation
- ✅ Refund processing
- ✅ Transaction logging

### Trip & Booking Flow
- ✅ Trip creation with geocoding
- ✅ Geospatial trip search
- ✅ Quote generation via Cost Service
- ✅ Booking confirmation with payment
- ✅ Booking cancellation with refund
- ✅ Rating system (bidirectional)

---

## 🔧 Service Details

### Auth Service (Port 3001)
- User registration with SJSU ID upload
- Login with JWT token generation
- Token refresh
- Password hashing with bcrypt

### User Service (Port 3002)
- Profile management (CRUD)
- Driver profile setup
- Rating aggregation
- User statistics

### Trip Service (Port 3003)
- **Geocoding**: Converts addresses to coordinates
- **PostGIS**: Spatial queries for nearby trips
- **CRUD**: Create, read, update, cancel trips
- **Filters**: By driver, status, departure time

### Booking Service (Port 3004)
- **Quote Generation**: Calls Cost Service
- **Payment Integration**: Calls Payment Service
- **Seat Management**: Reduces trip seats on confirm
- **Ratings**: Create ratings for completed trips

### Payment Service (Port 3005)
- **Stripe Integration**: Full payment processing
- **Payment Intents**: Create and confirm
- **Refunds**: Process refunds for cancelled bookings

### Cost Calculation Service (Port 3009)
- **Simple Algorithm**: base_price + (distance × price_per_mile) / num_riders
- **ML Interface**: Clear TODOs for advanced pricing models
- **Extensible**: Easy to swap in ML-based pricing

### Grouping Service (Port 8001 - Python)
- **Distance-Based Matching**: Finds trips within radius
- **Simple Scoring**: Based on origin/destination proximity
- **ML Interface**: Documented integration points for ML models
- **PostgreSQL**: Direct PostGIS queries

### Routing Service (Port 8002 - Python)
- **Google Maps**: Distance Matrix API integration
- **Redis Caching**: 1-hour TTL for route calculations
- **Distance & Duration**: Returns meters, miles, seconds

### Notification Service (Port 3006)
- **Email Stubs**: Console logging (integrate SendGrid/SES)
- **Push Stubs**: Console logging (integrate FCM)
- **Ready for Integration**: Clear interface for real services

### API Gateway (Port 3000)
- **Request Routing**: Proxies to all services
- **JWT Validation**: Verifies tokens on protected routes
- **Rate Limiting**: 100 requests per 15 minutes
- **CORS**: Configured for cross-origin requests
- **Error Handling**: Standardized error responses

---

## 📊 Database Schema

See individual migration files in `shared/database/migrations/` for complete schema.

**Core Tables:**
- `users` - User accounts with SJSU verification
- `trips` - Trip postings with PostGIS points
- `bookings` - Booking requests
- `quotes` - Pricing quotes ("never increase" guarantee)
- `payments` - Stripe payment records
- `ratings` - Bidirectional ratings (driver ↔ rider)

---

## 🧪 Test Data

After running `npm run seed`:

**Users:**
- Emails: `user1@sjsu.edu` through `user50@sjsu.edu`
- Password: `Password123`
- 25 Drivers, 25 Riders
- All SJSU verified

**Trips:**
- 100 trips originating near SJSU campus
- Destinations: SF, Oakland, Palo Alto, etc.
- 70 active, 20 completed, 10 cancelled

**Bookings:**
- 50 bookings with quotes
- Mix of pending, confirmed, completed, cancelled
- Payments for confirmed bookings

---

## 🐛 Troubleshooting

### PostgreSQL Connection Error
```bash
# Ensure PostgreSQL is running
docker-compose up -d postgres

# Check logs
docker-compose logs postgres
```

### Redis Connection Error
```bash
# Ensure Redis is running
docker-compose up -d redis

# Check logs
docker-compose logs redis
```

### Google Maps API Errors
- Verify API key is set in `.env`
- Ensure Geocoding API and Distance Matrix API are enabled in Google Cloud Console
- Check API quotas

### Stripe Errors
- Use test keys (sk_test_...)
- Use test cards: `4242 4242 4242 4242`

### Port Already in Use
```bash
# Find process using port
lsof -i :3000  # Mac/Linux
netstat -ano | findstr :3000  # Windows

# Kill process or change port in service's .env
```

---

## 🚀 Next Steps

### For Production
1. **Environment Variables**: Set production values for all secrets
2. **HTTPS**: Configure SSL/TLS
3. **CORS**: Restrict allowed origins
4. **Rate Limiting**: Adjust limits based on traffic
5. **Monitoring**: Add Prometheus + Grafana
6. **Logging**: Implement centralized logging (ELK stack)
7. **Docker Compose**: Add service containers
8. **CI/CD**: Setup GitHub Actions
9. **Backups**: Configure database backups

### ML Model Integration
1. **Cost Calculation**: Replace simple formula with ML pricing model
   - See TODOs in `services/cost-calculation-service/src/app.ts`

2. **Grouping Service**: Integrate compatibility prediction model
   - See TODOs in `services/grouping-service/app/main.py`

### Feature Enhancements
1. **Real-time Tracking**: WebSocket integration
2. **Safety Features**: Implement Safety Service
3. **Admin Portal**: User verification, incident management
4. **Notifications**: Integrate FCM and SendGrid
5. **Analytics**: Track metrics, generate reports

---

## 📞 Support

For issues or questions:
- Check [docs/api/endpoints.md](docs/api/endpoints.md) for API details
- Review service READMEs in `services/*/README.md`
- Check logs for error details

---

**Built with ❤️ for SJSU Smart Carpooling**
