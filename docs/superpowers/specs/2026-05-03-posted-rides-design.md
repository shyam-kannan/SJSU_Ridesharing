# Posted Rides Feature Design

## Overview

Convert the ridesharing system from an on-demand model to a posted rides model where drivers post scheduled trips and riders search and select from available trips.

## Architecture

### Current State
- On-demand matching: drivers toggle availability → riders make requests → matching algorithm
- Uses ML-based matching pipeline (PostGIS → embedding → Scost)
- Trip requests stored in `trip_requests` table with `pending_matches`

### Target State
- Posted rides: drivers post scheduled trips → riders search and select → bookings require driver approval
- Reuse existing ML matching pipeline for search ranking
- On-demand matching kept for backward compatibility but not promoted in UI

## Backend API Changes

### 1. Database Schema Changes

#### Migration: `020_enhance_trip_booking_flow.sql`

```sql
-- Add featured flag to trips table
ALTER TABLE trips ADD COLUMN featured BOOLEAN DEFAULT false;

-- Add max_riders to trips table
ALTER TABLE trips ADD COLUMN max_riders INTEGER DEFAULT seats_available;

-- Add booking_state to bookings table
ALTER TABLE bookings ADD COLUMN booking_state VARCHAR(20) DEFAULT 'pending';

-- Create index on booking_state for fast filtering
CREATE INDEX idx_bookings_booking_state ON bookings(booking_state);

-- Add SJSU location validation
-- Note: SJSU coordinates (37.3352, -122.8811) with ~0.5 mile radius
-- This will be enforced at API level, not DB level for flexibility
```

#### New Booking States

```typescript
enum BookingState {
  Pending = 'pending',      // Awaiting driver approval
  Approved = 'approved',    // Driver approved the booking
  Rejected = 'rejected',    // Driver rejected the booking
  Cancelled = 'cancelled',  // Booking cancelled by rider or driver
  Completed = 'completed'   // Trip completed
}
```

### 2. Trip Service Enhancements

#### Enhanced Search Endpoint

**Endpoint:** `GET /api/trips/search`

**Query Parameters:**
- `sjsu_direction`: 'to_sjsu' | 'from_sjsu' | 'either'
- `origin_lat`: number (required)
- `origin_lng`: number (required)
- `destination_lat`: number (optional, for 'from_sjsu' direction)
- `destination_lng`: number (optional, for 'from_sjsu' direction)
- `departure_after`: ISO 8601 datetime (optional)
- `departure_before`: ISO 8601 datetime (optional)
- `min_seats`: number (optional, default: 1)
- `limit`: number (optional, default: 10, max: 50)
- `offset`: number (optional, default: 0, for pagination)

**Response:**
```typescript
{
  trips: TripWithDriver[],
  total: number,
  has_more: boolean
}
```

**ML Matching Integration:**

The search will use the existing three-stage matching pipeline:

1. **PostGIS Proximity Filter** (5km radius, ±30 min departure window)
2. **RShareForm Embedding Ranking** (HIN embeddings based on location zones and time of day)
3. **Scost Ranking** (detour distance, walking distance, extra distance penalty, waiting time, route compatibility)

**Implementation:**
- Adapt existing `matching.service.ts` to work with search instead of on-demand matching
- Return ranked list of trips with similarity scores
- Apply pagination at the result level

#### Trip Creation Validation

**Endpoint:** `POST /api/trips`

**Validation:**
- Verify driver has complete vehicle profile
- Enforce SJSU requirement: origin or destination must be within ~0.5 miles of SJSU coordinates (37.3352, -122.8811)
- Check for overlapping trips (existing logic)
- Validate recurrence pattern if provided

**Error Responses:**
- 400: Invalid trip data (non-SJSU location, overlapping trip, etc.)
- 403: Driver profile incomplete
- 409: Overlapping trip exists

### 3. Booking Service Enhancements

#### Booking Creation

**Endpoint:** `POST /api/bookings`

**Request:**
```typescript
{
  trip_id: string,
  seats_booked: number
}
```

**Response:**
```typescript
{
  booking: Booking,
  quote: Quote
}
```

**Logic:**
- Create booking with `booking_state = 'pending'`
- Check trip availability (seats, status)
- Prevent duplicate bookings
- Generate quote via cost service
- Send notification to driver

#### Booking Approval

**Endpoint:** `PATCH /api/bookings/:id/approve`

**Authorization:** Driver only

**Logic:**
- Verify user is the driver of the trip
- Update `booking_state = 'approved'`
- Deduct seats from trip
- Send notification to rider
- Return updated booking

#### Booking Rejection

**Endpoint:** `PATCH /api/bookings/:id/reject`

**Authorization:** Driver only

**Logic:**
- Verify user is the driver of the trip
- Update `booking_state = 'rejected'`
- Send notification to rider
- Return updated booking

#### Get Trip Bookings

**Endpoint:** `GET /api/bookings/trip/:tripId`

**Authorization:** Driver only

**Response:**
```typescript
{
  bookings: BookingWithRider[],
  total: number
}
```

**Logic:**
- Return all bookings for the trip
- Include rider details (name, rating, profile picture)
- Filter by booking state if needed

### 4. Notification Service Updates

**New Notification Types:**

1. **booking_request** - Sent to driver when rider requests a ride
   ```typescript
   {
     type: 'booking_request',
     title: 'New Booking Request',
     message: '{rider_name} requested a seat on your {time} trip',
     data: {
       trip_id: string,
       booking_id: string,
       rider_name: string,
       seats_booked: number
     }
   }
   ```

2. **booking_approved** - Sent to rider when driver approves
   ```typescript
   {
     type: 'booking_approved',
     title: 'Ride Confirmed',
     message: 'Your ride from {origin} to {destination} is confirmed',
     data: {
       trip_id: string,
       booking_id: string,
       driver_name: string
     }
   }
   ```

3. **booking_rejected** - Sent to rider when driver rejects
   ```typescript
   {
     type: 'booking_rejected',
     title: 'Request Declined',
     message: 'Your request was declined. Browse other rides.',
     data: {
       trip_id: string,
       booking_id: string
     }
   }
   ```

## iOS UI/UX Changes

### 1. Rider Home View Updates

**Current State:**
- Full-screen map with user location
- Direction picker (To SJSU / From SJSU) - locks in SJSU as destination or origin
- Location input for the non-SJSU location with autocomplete
- Departure time picker
- "Request Ride" button (triggers on-demand matching)

**New State:**
- Keep existing map and direction picker (TO/FROM SJSU selection)
- Keep existing location input for the non-SJSU location
- Keep existing departure time picker
- Change button to "Search Rides"
- On submit: navigate to RiderSearchResultsView with search results

**Flow:**
1. Rider opens app → sees map
2. Selects "To SJSU" or "From SJSU" → locks in SJSU as destination or origin
3. Enters their other location (the non-SJSU one) with autocomplete
4. Selects departure time
5. Taps "Search Rides" → navigates to RiderSearchResultsView

**State Management:**
- `RiderHomeViewModel` will handle search state
- Store search criteria (direction, non-SJSU location, time)
- Pass to search results view

### 2. Rider Search Results View (New)

**File:** `LessGo/Core/Rider/Views/RiderSearchResultsView.swift`

**Components:**
- Header with search criteria summary
- List of trip cards (top 10 initially)
- Loading indicator for pagination
- Empty state when no results found
- Error state when search fails

**Trip Card (List Item):**
- Driver photo, name, rating
- Origin → destination
- Departure time
- Seats available
- Estimated cost
- Tap to view details

**Pagination:**
- Load next 10 when user scrolls to bottom
- Show loading indicator during fetch
- Stop when no more results

**ViewModel:** `RiderSearchResultsViewModel.swift`
- Manage search results state
- Handle pagination
- Cache search criteria for refresh

### 3. Trip Detail View (New)

**File:** `LessGo/Core/Rider/Views/TripDetailView.swift`

**Components:**
- Driver profile section (photo, name, rating, vehicle info)
- Trip details (origin, destination, departure time, seats left)
- Cost breakdown
- Route map visualization
- "Request Ride" button (if not booked)
- Booking status indicator (if booked)
- Chat button (reuse existing chat implementation)

**Booking States:**
- **Not Booked**: Show "Request Ride" button
- **Pending**: Show "Awaiting approval..." with cancel button
- **Approved**: Show driver contact info and "Confirmed" status
- **Rejected**: Show "Request declined" message with option to search again

**ViewModel:** `TripDetailViewModel.swift`
- Manage booking state
- Poll for booking status updates (every 3 seconds)
- Handle booking actions (request, cancel)

### 4. Driver Home View Updates

**Current State:**
- Availability toggle
- Active trip banner
- Recent activity

**New State:**
- Keep availability toggle (for backward compatibility)
- Add "Your Posted Rides" section
- Show list of upcoming trips with pending bookings count
- Tap trip → navigate to existing DriverTripDetailView (in Lists tab)

### 5. Driver Trip Detail View (Existing)

**File:** `LessGo/Core/Driver/Views/DriverTripDetailView.swift` (already exists)

**Current Components:**
- Trip details (origin, destination, departure time, seats left)
- List of passengers
- Trip state management

**New Components to Add:**
- Pending bookings section with rider info
- Approve/Reject buttons for each pending booking
- Edit seats available button
- View rider profile option
- Chat button (reuse existing chat implementation)

**Booking Management:**
- Show rider photo, name, rating for pending bookings
- Approve/Reject buttons for each pending booking
- View rider profile option
- Chat button (reuse existing chat implementation)

**State Management:**
- Refresh bookings list periodically
- Update UI on booking state changes
- Handle approve/reject actions

## Data Flow

### Rider Search Flow

```
1. Rider enters search criteria (direction, location, time)
   ↓
2. Rider taps "Search Rides"
   ↓
3. RiderHomeViewModel calls TripService.searchTrips()
   ↓
4. TripService calls matching.service.ts with search criteria
   ↓
5. Matching service runs three-stage pipeline:
   - PostGIS proximity filter
   - RShareForm embedding ranking
   - Scost ranking
   ↓
6. Results returned to RiderSearchResultsView
   ↓
7. Display top 10 trips as cards
   ↓
8. User scrolls → load next 10 (pagination)
```

### Booking Flow

```
1. Rider taps on trip card
   ↓
2. Navigate to TripDetailView
   ↓
3. Rider taps "Request Ride"
   ↓
4. TripDetailViewModel calls BookingService.createBooking()
   ↓
5. BookingService creates booking with state='pending'
   ↓
6. Notification sent to driver
   ↓
7. TripDetailView shows "Awaiting approval..."
   ↓
8. Poll for booking status every 3 seconds
   ↓
9. When approved → show driver contact info
```

### Driver Approval Flow

```
1. Driver receives notification
   ↓
2. Driver taps notification → navigate to DriverTripDetailView
   ↓
3. Driver sees pending booking list
   ↓
4. Driver taps "Approve" on a booking
   ↓
5. DriverTripDetailView calls BookingService.approveBooking()
   ↓
6. BookingService updates state='approved'
   ↓
7. Notification sent to rider
   ↓
8. DriverTripDetailView updates UI
```

## Error Handling

### API Errors

**400 Bad Request:**
- Invalid search criteria
- Non-SJSU location
- Overlapping trip
- Invalid booking data

**401 Unauthorized:**
- Missing or invalid token

**403 Forbidden:**
- Driver profile incomplete
- Not authorized to approve/reject booking

**404 Not Found:**
- Trip not found
- Booking not found

**409 Conflict:**
- Duplicate booking
- Overlapping trip

**500 Internal Server Error:**
- ML matching service unavailable
- Database error
- Notification service error

### UI Error States

**Search Errors:**
- Show error banner with retry button
- Allow user to modify search criteria

**Booking Errors:**
- Show error message in TripDetailView
- Allow user to try again or search for other trips

**Network Errors:**
- Show offline indicator
- Cache last known state
- Retry on reconnect

## Testing Strategy

### Backend Tests

**Unit Tests:**
- Trip search with various filters
- Booking creation and state transitions
- ML matching pipeline (mock embedding service)
- SJSU location validation

**Integration Tests:**
- End-to-end search flow
- Booking approval flow
- Notification delivery
- Pagination

**Load Tests:**
- Concurrent search requests
- High volume of bookings
- ML matching performance

### iOS Tests

**Unit Tests:**
- ViewModels (RiderHomeViewModel, RiderSearchResultsViewModel, TripDetailViewModel)
- Service layer (TripService, BookingService)

**UI Tests:**
- Search flow
- Booking flow
- Driver approval flow
- Pagination

**E2E Tests:**
- Complete rider journey (search → book → approve)
- Driver journey (post trip → approve → complete)

## Future Enhancements

### Phase 2 Features

1. **Advanced Filters**
   - Driver rating threshold
   - Vehicle type
   - Price range
   - Preferred departure time window

2. **Caching Layer**
   - Redis cache for ML results
   - Cache invalidation on trip changes
   - Improved performance for high-volume searches

3. **Recurring Trip Management**
   - Edit recurring trips
   - Cancel individual instances
   - View recurring trip history

4. **Analytics**
   - Posted vs on-demand usage
   - Search patterns
   - Booking conversion rates

## Implementation Phases

### Phase 1: Core Backend (Week 1-2)
- Database migration
- Enhanced search endpoint with ML integration
- Booking approval endpoints
- Notification updates

### Phase 2: Rider UI (Week 2-3)
- RiderHomeView updates
- RiderSearchResultsView
- TripDetailView
- Booking state management

### Phase 3: Driver UI (Week 3-4)
- DriverHomeView updates
- DriverTripDetailView
- Booking management UI

### Phase 4: Testing & Polish (Week 4-5)
- Backend testing
- iOS testing
- E2E testing
- Bug fixes

### Phase 5: Deployment (Week 5)
- Backend deployment
- iOS app store submission
- Monitoring setup

## Success Criteria

1. **Functional:**
   - Riders can search for posted trips
   - Riders can book trips and receive approval
   - Drivers can approve/reject bookings
   - ML matching returns relevant results

2. **Performance:**
   - Search returns results in < 2 seconds
   - Pagination loads smoothly
   - Booking state updates in real-time

3. **UX:**
   - Intuitive search flow
   - Clear booking status
   - Responsive UI

4. **Reliability:**
   - 99.9% uptime for search API
   - Notifications delivered within 5 seconds
   - Error handling graceful
