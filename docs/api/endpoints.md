# LessGo Backend API Documentation

Base URL: `http://localhost:3000/api` (via API Gateway)

All authenticated endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <access_token>
```

---

## Authentication Service (Port 3001)

### POST /api/auth/register
Register a new user with optional SJSU ID upload

**Request:**
```json
{
  "name": "John Doe",
  "email": "john@sjsu.edu",
  "password": "Password123",
  "role": "Driver" or "Rider"
}
```

**File Upload:** `sjsuId` (optional image file)

**Response:** User object + access & refresh tokens

---

### POST /api/auth/login
Login with email and password

**Request:**
```json
{
  "email": "john@sjsu.edu",
  "password": "Password123"
}
```

**Response:** User object + access & refresh tokens

---

### POST /api/auth/refresh
Refresh access token

**Request:**
```json
{
  "refreshToken": "<refresh_token>"
}
```

**Response:** New access token

---

### GET /api/auth/verify
Verify token validity

**Headers:** Authorization: Bearer <token>

**Response:** Token validity status + user info

---

### GET /api/auth/me
Get current user profile

**Headers:** Authorization: Bearer <token>

**Response:** Current user object

---

## User Service (Port 3002)

### GET /api/users/me
Get current user's profile (authenticated)

**Response:** User profile

---

### GET /api/users/:id
Get user by ID (public)

**Response:** User profile

---

### PUT /api/users/:id
Update user profile (own profile only)

**Request:**
```json
{
  "name": "New Name",
  "email": "newemail@sjsu.edu"
}
```

**Response:** Updated user profile

---

### PUT /api/users/:id/driver-setup
Setup driver profile

**Request:**
```json
{
  "vehicle_info": "Toyota Camry 2020",
  "seats_available": 3
}
```

**Response:** Updated user with driver role

---

### GET /api/users/:id/ratings
Get user's ratings

**Response:** Array of ratings with average score

---

### GET /api/users/:id/stats
Get user statistics

**Response:** Total trips, bookings, ratings, average rating

---

## Trip Service (Port 3003)

### POST /api/trips
Create a new trip (Driver only, verified SJSU ID required)

**Request:**
```json
{
  "origin": "123 Main St, San Jose, CA",
  "destination": "San Francisco, CA",
  "departure_time": "2024-12-25T08:00:00Z",
  "seats_available": 3,
  "recurrence": "M/W/F" (optional)
}
```

**Response:** Created trip with geocoded coordinates

---

### GET /api/trips/search
Search trips near a location

**Query Parameters:**
- `origin_lat` (required)
- `origin_lng` (required)
- `radius_meters` (optional, default 5000)
- `min_seats` (optional)
- `departure_after` (optional, ISO 8601)
- `departure_before` (optional, ISO 8601)

**Response:** Array of matching trips

---

### GET /api/trips
List trips with filters

**Query Parameters:**
- `driver_id` (optional)
- `status` (optional: active/completed/cancelled)
- `departure_after` (optional)
- `limit` (optional, default 100)

**Response:** Array of trips

---

### GET /api/trips/:id
Get trip details

**Response:** Trip with driver information

---

### PUT /api/trips/:id
Update trip (own trip only)

**Request:**
```json
{
  "departure_time": "2024-12-26T08:00:00Z",
  "seats_available": 2,
  "recurrence": "M/W"
}
```

**Response:** Updated trip

---

### DELETE /api/trips/:id
Cancel trip (own trip only)

**Response:** Cancelled trip

---

## Booking Service (Port 3004)

### POST /api/bookings
Create a new booking (verified SJSU ID required)

**Request:**
```json
{
  "trip_id": "uuid",
  "seats_booked": 1
}
```

**Response:** Booking + quote

---

### GET /api/bookings
List user's bookings

**Query Parameters:**
- `as_driver` (optional, boolean)

**Response:** Array of bookings with details

---

### GET /api/bookings/:id
Get booking details

**Response:** Booking with trip, rider, quote, payment

---

### PUT /api/bookings/:id/confirm
Confirm booking (creates payment)

**Response:** Updated booking with payment

---

### PUT /api/bookings/:id/cancel
Cancel booking (refunds payment if confirmed)

**Response:** Cancelled booking

---

### POST /api/bookings/:id/rate
Rate completed booking

**Request:**
```json
{
  "score": 5,
  "comment": "Great ride!"
}
```

**Response:** Created rating

---

## Payment Service (Port 3005)

### POST /api/payments/create-intent
Create Stripe payment intent

**Request:**
```json
{
  "booking_id": "uuid",
  "amount": 25.50
}
```

**Response:** Payment record with Stripe PaymentIntent ID

---

### POST /api/payments/:id/capture
Capture payment

**Response:** Updated payment with captured status

---

### POST /api/payments/:id/refund
Refund payment

**Response:** Updated payment with refunded status

---

### GET /api/payments/booking/:bookingId
Get payment by booking ID

**Response:** Payment record

---

## Notification Service (Port 3006)

### POST /api/notifications/email
Send email notification (STUB)

**Request:**
```json
{
  "user_id": "uuid",
  "email": "user@sjsu.edu",
  "subject": "Subject",
  "message": "Message body"
}
```

**Response:** Success (logs to console)

---

### POST /api/notifications/push
Send push notification (STUB)

**Request:**
```json
{
  "user_id": "uuid",
  "title": "Title",
  "message": "Message"
}
```

**Response:** Success (logs to console)

---

## Grouping Service (Port 8001 - Python)

### POST /api/group/match
Find matching trips for a rider

**Request:**
```json
{
  "rider_id": "uuid",
  "origin_lat": 37.3352,
  "origin_lng": -122.8811,
  "destination_lat": 37.7749,
  "destination_lng": -122.4194,
  "departure_time": "2024-12-25T08:00:00Z",
  "seats_needed": 1
}
```

**Response:** Array of top 10 matching trips with scores

---

## Routing Service (Port 8002 - Python)

### POST /api/route/calculate
Calculate route distance and duration

**Request:**
```json
{
  "origin": "San Jose State University, CA",
  "destination": "San Francisco, CA"
}
```

**Response:**
```json
{
  "distance_meters": 80000,
  "distance_miles": 49.71,
  "duration_seconds": 3600,
  "polyline": null
}
```

---

## Cost Calculation Service (Port 3009)

### POST /api/cost/calculate
Calculate trip cost (simple placeholder algorithm)

**Request:**
```json
{
  "origin": "San Jose, CA",
  "destination": "San Francisco, CA",
  "num_riders": 2,
  "trip_id": "uuid"
}
```

**Response:**
```json
{
  "max_price": 15.50,
  "breakdown": {
    "base_price": 5.00,
    "distance_miles": 50.0,
    "price_per_mile": 0.50,
    "total_trip_cost": 30.00,
    "price_per_rider": 15.00
  }
}
```

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "status": "error",
  "message": "Error description",
  "errors": {} (optional validation errors)
}
```

**Common Status Codes:**
- 200: Success
- 201: Created
- 400: Bad Request
- 401: Unauthorized (missing token)
- 403: Forbidden (invalid token or insufficient permissions)
- 404: Not Found
- 409: Conflict
- 500: Internal Server Error
- 502: Service Unavailable

---

## Rate Limiting

API Gateway enforces rate limiting:
- **Window:** 15 minutes
- **Max Requests:** 100 per window
- **Applies to:** All /api/* endpoints

Exceeded rate limit returns 429 with:
```json
{
  "status": "error",
  "message": "Too many requests, please try again later"
}
```

---

## CORS

All origins allowed in development. In production, configure specific origins.

---

## Health Checks

- **API Gateway:** GET /health
- **Individual Services:** GET /health (on service ports)

Returns service status and configuration info.
