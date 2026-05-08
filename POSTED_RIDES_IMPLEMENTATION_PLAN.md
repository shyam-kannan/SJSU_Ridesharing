# Plan: Convert from On-Demand to Posted Rides Model

## TL;DR
Shift the ridesharing system from an Uber-like on-demand model (drivers toggle availability → riders make requests → matching algorithm) to a posted rides model (drivers post scheduled trips → riders search and select → bookings require driver approval).

**Rider Discovery Flow:** From the rider home page (map with TO/FROM SJSU selection), riders lock in SJSU as destination or origin, enter their other location, select date/time, then get a filtered list of matching driver-posted trips using the existing ML-based matching pipeline.

**ML Matching Pipeline:** The system uses a three-stage matching pipeline:
1. **PostGIS proximity filter** - 5km radius, ±30 min departure window
2. **RShareForm embedding ranking** - HIN embeddings based on location zones and time of day
3. **Scost ranking** - Considers detour distance, walking distance, extra distance penalty, waiting time, and route compatibility

**Pagination:** Load top 10 results initially, then next 10 on scroll (infinite scroll). Each trip is a card showing minimum details; tap to view full details with cost breakdown.

**Chat Integration:** Reuse existing chat implementation for rider-driver communication.

Availability toggle remains optional. Bookings require driver approval. SJSU requirement is technically enforced using hardcoded coordinates (37.3352, -122.8811) with ~0.5 mile radius. The infrastructure is 40% ready—`CreateTripView` and `/api/trips` POST endpoint exist but need wiring and matching logic refactor.

---

## Implementation Steps

### Phase 1: Backend API & Database Enhancements

**1.1 Update trip schema for new workflow**
- Add `featured` (boolean) to trips table—drivers can promote certain routes for visibility
- Add `max_riders` (integer) to trips table—limit concurrent bookings per trip
- Update `bookings` table: add `booking_state` (ENUM: 'pending', 'approved', 'rejected', 'cancelled', 'completed') to track driver approval flow
- Migration: new columns with sensible defaults (featured=false, max_riders=seats_available, booking_state='pending')
- Create index on booking_state for fast filtering
- *Reference*: `db/migrations/` - follow naming convention `020_enhance_trip_booking_flow.sql`

**1.2 Enforce SJSU requirement at API level**
- Add SJSU location validation in trip creation
- Check: geocode the location and verify it's within ~0.5 miles of SJSU coordinates (37.3352, -122.8811)
- If neither origin nor destination is SJSU, return 400 error with helpful message
- Note: Rider home page already locks in SJSU as starting or ending point via TO/FROM selection, so this is primarily for driver trip creation validation
- *File*: `services/trip-service/src/controllers/trip.controller.ts` - update createTrip validation

**1.3 Create trip search endpoint enhancements**
- Enhance `GET /api/trips/search` to support:
  - `sjsu_direction` query param: 'to_sjsu', 'from_sjsu', 'either'
  - `origin_lat`, `origin_lng` - the rider's non-SJSU location coordinates
  - `destination_lat`, `destination_lng` - the rider's non-SJSU destination (for 'from_sjsu' direction)
  - `departure_after`, `departure_before` - time range (ISO 8601)
  - `min_seats` - minimum seats available
  - `limit` - number of results to return (default: 10, max: 50)
  - `offset` - for pagination (default: 0)
- Return trip with driver profile info: name, rating, vehicle_info, profile_picture_url
- **ML Matching Integration**: Use existing three-stage matching pipeline:
  1. PostGIS proximity filter (5km radius, ±30 min departure window)
  2. RShareForm embedding ranking (HIN embeddings based on location zones and time of day)
  3. Scost ranking (detour distance, walking distance, extra distance penalty, waiting time, route compatibility)
- Apply pagination at result level (LIMIT/OFFSET)
- *File*: `services/trip-service/src/controllers/trip.controller.ts`
- *File*: `services/trip-service/src/services/matching.service.ts` - adapt for search instead of on-demand matching

**1.4 Add booking approval flow endpoints**
- `PATCH /api/bookings/:id/approve` (driver only) - driver approves rider's booking
  - Verify user is the driver of the trip
  - Update `booking_state = 'approved'`
  - Deduct seats from trip
  - Send notification to rider
  - Return updated booking
- `PATCH /api/bookings/:id/reject` (driver only) - driver rejects booking
  - Verify user is the driver of the trip
  - Update `booking_state = 'rejected'`
  - Send notification to rider
  - Return updated booking
- `PATCH /api/bookings/:id/cancel` (rider only if pending; driver can cancel anytime)
- Each endpoint updates `booking_state` and triggers notifications
- *File*: `services/booking-service/src/controllers/booking.controller.ts`

**1.5 Update booking creation flow**
- Rider selects a posted trip → creates booking with `booking_state = 'pending'`
- Endpoint: `POST /api/bookings` (existing, just need to ensure booking_state is set)
- Check trip availability (seats, status)
- Prevent duplicate bookings
- Generate quote via cost service
- Trigger notification to driver: "New booking request from [rider name] for your [time] trip"
- *File*: `services/booking-service/src/controllers/booking.controller.ts`

**1.6 Add booking approval notification flow**
- When driver approves: send push notification to rider "Your ride has been confirmed!"
- When driver rejects: send notification to rider "Request declined" + allow rider to browse other trips
- *File*: `services/notification-service/` - update notification templates

**1.7 Update shared types**
- Add BookingState ENUM: 'pending', 'approved', 'rejected', 'cancelled', 'completed'
- Update CreateTripRequest type if needed
- *File*: `shared/types/index.ts`

### Phase 2: iOS UI/UX - Rider Side

**2.1 Update RiderHomeView** (search-based discovery from home page)
- Keep existing full-screen map with user location
- Keep existing direction picker (TO/FROM SJSU selection) - this locks in SJSU as destination or origin
- Keep existing location input for the non-SJSU location with autocomplete
- Keep existing departure time picker
- Change button from "Request Ride" to "Search Rides"
- On submit: navigate to RiderSearchResultsView with search results
- Show rider's upcoming bookings (both pending and confirmed) below search form
- *File*: `LessGo/Core/Home/Views/RiderHomeView.swift`
- *ViewModel*: Update `LessGo/Core/Home/ViewModels/RiderHomeViewModel.swift` to handle search state

**2.2 Create RiderSearchResultsView** (new screen, shown after search)
- Display list of matching trips returned from `GET /api/trips/search`
- Header with search criteria summary
- List of trip cards (top 10 initially)
- Each trip card shows:
  - Driver photo, name, rating
  - Origin → destination
  - Departure time
  - Seats available
  - Estimated cost
- Tap card → navigate to TripDetailView with full details
- Back button returns to search form
- Pagination: Load next 10 when user scrolls to bottom
- Loading indicator during fetch
- Empty state when no results found
- Error state when search fails
- *File*: `LessGo/Core/Rider/Views/RiderSearchResultsView.swift` (create new)
- *ViewModel*: `LessGo/Core/Rider/ViewModels/RiderSearchResultsViewModel.swift` (create new)

**2.3 Create TripDetailView** (new screen)
- Shows full trip details:
  - Driver profile section: photo, name, rating, vehicle info
  - Trip info: origin, destination, departure time, seats left, recurrence pattern
  - Cost breakdown
  - Route map visualization
  - Chat button (reuse existing chat implementation)
- "Request Ride" button (if not booked) → creates pending booking
- Booking states:
  - **Not Booked**: Show "Request Ride" button
  - **Pending**: Show "Awaiting approval..." with cancel button
  - **Approved**: Show driver contact info and "Confirmed" status
  - **Rejected**: Show "Request declined" message with option to search again
- Auto-refresh booking state every 3 seconds via polling
- *File*: `LessGo/Core/Rider/Views/TripDetailView.swift` (create new)
- *ViewModel*: `LessGo/Core/Rider/ViewModels/TripDetailViewModel.swift` (create new)

### Phase 3: iOS UI/UX - Driver Side

**3.1 Wire up CreateTripView navigation**
- Add button to DriverHomeView: "Post a Ride" (primary action)
- Navigate to CreateTripView (already exists)
- *File*: `LessGo/Core/Home/Views/DriverHomeView.swift`
- *Reference*: CreateTripView is at `LessGo/Core/TripCreation/Views/CreateTripView.swift`

**3.2 Enhance CreateTripView recurrence UI**
- Current: optional recurrence field
- Add: visual calendar picker (M/W/F format → show as checkboxes)
- Add: end date for recurrence (e.g., "repeat until Dec 31")
- Validation: Don't allow recurrence if trip is in the past
- *File*: `LessGo/Core/TripCreation/Views/CreateTripView.swift`

**3.3 Update DriverHomeView dashboard**
- Keep availability toggle (optional for drivers who still want on-demand)
- Add section: "Your Posted Rides" (list of upcoming trips)
  - Show: origin → destination, departure time, seats left, number of pending bookings
  - Tap trip → navigate to existing DriverTripDetailView (in Lists tab)
- *File*: `LessGo/Core/Home/Views/DriverHomeView.swift`

**3.4 Update DriverTripDetailView** (existing file in Lists tab)
- Add pending bookings section with rider info
- For each pending booking:
  - Show rider photo, name, rating
  - Approve/Reject buttons
  - View rider profile option
  - Chat button (reuse existing chat implementation)
- Add edit seats available button
- Add cancel trip button
- Keep existing trip state management
- *File*: `LessGo/Core/Driver/Views/DriverTripDetailView.swift` (already exists, update)

**3.5 Add ongoing trip indicators**
- Active trip banner at top of dashboard (if trip is en_route, arrived, in_progress)
- Show rider name, destination, ETA
- Tap to view ActiveTripView (already exists)
- *File*: `LessGo/Core/Home/Views/DriverHomeView.swift`

### Phase 4: Backend Matching Logic Refactor

**4.1 Adapt ML matching pipeline for search**
- Reuse existing three-stage matching pipeline for rider search:
  1. PostGIS proximity filter (5km radius, ±30 min departure window)
  2. RShareForm embedding ranking (HIN embeddings based on location zones and time of day)
  3. Scost ranking (detour distance, walking distance, extra distance penalty, waiting time, route compatibility)
- Adapt `matching.service.ts` to work with search instead of on-demand matching
- Return ranked list of trips with similarity scores
- Apply pagination at the result level
- *File*: `services/trip-service/src/services/matching.service.ts`

**4.2 Disable/deprecate on-demand matching**
- On-demand matching (trip_requests + pending_matches) should still exist but be secondary
- When availability_toggle = true AND no posted trips: use old matching
- When driver has posted trips: disable on-demand matching (don't process trip_requests for this driver)
- *File*: `services/trip-service/src/services/matching.service.ts`

### Phase 5: Data Migration & Cleanup

**5.1 Handle existing on-demand requests**
- Expire all pending `trip_requests` with status 'pending' (they won't match to posted trips automatically)
- Set their status to 'expired' or 'cancelled'
- Notify affected riders: "Your ride request expired. Browse posted rides instead."

**5.2 Deprecation warning for trip_requests table**
- Mark table as deprecated in schema docs
- Note: keep for backward compatibility until on-demand fully removed
- *File*: Add comment in migration or README

---

## Relevant Files to Modify

**Backend:**
- `services/trip-service/src/controllers/trip.controller.ts` - enhance search, update validators
- `services/trip-service/src/services/matching.service.ts` - adapt ML matching for search, deprecate on-demand matching
- `services/booking-service/src/controllers/booking.controller.ts` - add approval endpoints
- `services/booking-service/src/services/booking.service.ts` - update booking creation and approval logic
- `services/notification-service/` - update notification templates
- `services/embedding-service/` - RShareForm HIN embedding service (existing, reuse for search ranking)
- `db/migrations/020_enhance_trip_booking_flow.sql` - new migration
- `shared/types/index.ts` - update BookingState ENUM, CreateTripRequest type

**iOS Frontend:**
- `LessGo/Core/Home/Views/DriverHomeView.swift` - add "Post Ride" button, wire navigation, add "Your Posted Rides" section
- `LessGo/Core/Home/Views/RiderHomeView.swift` - change button to "Search Rides", navigate to search results
- `LessGo/Core/Home/ViewModels/RiderHomeViewModel.swift` - handle search state
- `LessGo/Core/TripCreation/Views/CreateTripView.swift` - enhance recurrence UI, validate SJSU
- `LessGo/Core/Rider/Views/RiderSearchResultsView.swift` - **create new**
- `LessGo/Core/Rider/Views/TripDetailView.swift` - **create new**
- `LessGo/Core/Rider/ViewModels/RiderSearchResultsViewModel.swift` - **create new**
- `LessGo/Core/Rider/ViewModels/TripDetailViewModel.swift` - **create new**
- `LessGo/Core/Driver/Views/DriverTripDetailView.swift` - **update existing** (add pending bookings, approve/reject buttons, chat button)

---

## Verification Steps

1. **Backend API Verification:**
   - `POST /api/trips` with SJSU location enforcement:
     - ✅ Accept: origin="123 Main St, SJSU, CA"
     - ❌ Reject: origin="Downtown SF", destination="Oakland" (no SJSU)
   - `GET /api/trips/search?sjsu_direction=to_sjsu&origin_lat=...&origin_lng=...&departure_after=...` returns only trips matching filters
   - Search results are ranked using ML matching pipeline (PostGIS → embedding → Scost)
   - Pagination works: limit=10, offset=10 returns next 10 results
   - `POST /api/bookings` creates booking with `booking_state='pending'`
   - `PATCH /api/bookings/:id/approve` updates state and sends notification
   - `PATCH /api/bookings/:id/reject` updates state and sends notification
   - Recurring trips expand correctly in search results (e.g., daily trip shows 7 instances)

2. **iOS Rider Verification:**
   - RiderHomeView displays map with TO/FROM SJSU selection
   - Selecting "To SJSU" locks in SJSU as destination
   - Selecting "From SJSU" locks in SJSU as origin
   - Location input works for the non-SJSU location with autocomplete
   - Departure time picker works
   - "Search Rides" button triggers `GET /api/trips/search` and navigates to RiderSearchResultsView
   - RiderSearchResultsView shows list of matching trips with proper sorting (ML-ranked)
   - Each trip card shows driver photo, name, rating, origin → destination, departure time, seats available, estimated cost
   - Tap trip → TripDetailView shows driver profile and "Request Ride" button
   - TripDetailView shows cost breakdown
   - Chat button is present (reuses existing chat)
   - After requesting: TripDetailView shows "Awaiting approval..." with cancel button
   - Auto-refresh works (booking state updates in real-time every 3 seconds)
   - Notification received on phone when driver approves
   - After approval: Shows driver contact info and "Confirmed" status
   - Pagination works: scrolling to bottom loads next 10 results

3. **iOS Driver Verification:**
   - DriverHomeView has "Post a Ride" button → navigates to CreateTripView
   - CreateTripView validation rejects non-SJSU trips with error message
   - CreateTripView recurrence UI works with visual calendar picker
   - Posted trip appears in "Your Posted Rides" section immediately with pending bookings count
   - Tap trip → DriverTripDetailView shows pending bookings list
   - DriverTripDetailView shows rider photo, name, rating for each pending booking
   - Approve/Reject buttons work; rider gets notification
   - Chat button works (reuses existing chat)
   - Approved riders appear in trip detail with contact info
   - Edit seats available button works
   - Active trip banner shows when trip is en_route/in_progress

4. **Notification Verification:**
   - Driver receives push: "New booking request from Alice for your 9:00 AM trip"
   - Rider receives push: "Your ride has been confirmed! Driver: Bob"
   - Rejection notification: "Your request was declined. Browse other rides."

5. **Edge Cases:**
   - Duplicate bookings: rider tries to book same trip twice → prevent with endpoint logic
   - Overbooking: 5 riders book a 3-seat trip; 2nd and 3rd approved, 4th auto-rejected
   - Recurring trips: posting Mon/Wed/Fri trip on Friday should create instances for next week
   - No timeout: bookings remain pending until driver explicitly approves or rider cancels

---

## Decisions & Scope

**Included:**
- Dual-mode operation: availability toggle + posted rides
- SJSU requirement technically enforced (hardcoded coordinates 37.3352, -122.8811 with ~0.5 mile radius)
- Recurring trips with UI calendar picker
- Rider booking approval flow (pending → approved/rejected)
- Search-based discovery from rider home page (not browse-all)
- Driver dashboard showing posted rides and pending bookings
- Notifications for booking requests and approvals
- ML matching pipeline integration for search ranking
- Pagination (top 10, then next 10 on scroll)
- Chat integration (reuse existing implementation)
- No timeout for driver approval

**Explicitly Excluded (Future):**
- Rating/review system changes (existing ratings still apply)
- Payment integration changes (existing payment flow unchanged)
- On-demand matching deprecation (kept for backward compat, but not promoted in UI)
- Analytics/reporting on posted vs. on-demand usage
- Ride pooling optimization (drivers can post one trip; riders join individually)
- Map view for riders (search-based only in MVP)
- Advanced filters (driver rating threshold, vehicle type, price range) - can be added later
- Caching layer (Redis) - can be added later if performance becomes an issue

**Assumptions:**
- SJSU coordinates hardcoded as (37.3352, -122.8811) with ~0.5 mile radius
- Notification system already in place and functional
- Drivers must complete vehicle setup before posting trips (enforced at API level)
- Bookings remain in 'pending' state until driver explicitly approves (no auto-decline)
- Chat implementation already exists and will be reused
- DriverTripDetailView already exists in the Lists tab

---

## Further Considerations

1. **Recurring Trip Expansion**
   - Option A: Expand all recurring trips when posting (create 30 days worth immediately)
   - Option B: Expand on-the-fly during search (show "repeats Mon/Wed/Fri" with count, resolve at booking time)
   - Option C: Batch job runs nightly to create next week's instances
   - *Recommendation*: Start with **Option B** for simplicity; move to **Option C** if performance becomes an issue

2. **Booking Approval Timeout**
   - How long should riders wait for driver approval?
   - *Recommendation*: **No timeout** - bookings remain pending until driver explicitly approves or rider cancels. Removed per requirements.

3. **Ride Pooling / Seat Allocation**
   - Should riders be able to book multiple seats? (currently 1 seat default)
   - Should driver see total demand (3 bookings × 1 seat = 3 riders) before confirming?
   - *Recommendation*: **Allow multi-seat bookings**; show driver the breakdown in approval flow

4. **Caching for Advanced Filters**
   - Plan: Cache ML results and apply filters from cached results
   - Implementation: Redis cache with 2-5 minute TTL
   - Alternative: For MVP, run ML matching with all filters at query time (simpler)
   - *Recommendation*: Start with simpler approach (no caching) for MVP. Add Redis caching later if performance becomes an issue.

5. **Chat Integration**
   - Existing chat implementation will be reused
   - Each rider has a separate chat with the driver
   - Chat button added to TripDetailView and DriverTripDetailView
   - *Note*: This is already implemented, just need to wire up the buttons
