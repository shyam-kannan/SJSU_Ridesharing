# Rider/Driver UX Fixes & Seat Hold System — Design Spec

**Date:** 2026-05-06

## Overview

This spec covers a batch of interconnected bug fixes and features across the iOS app and backend services. Changes are grouped into four areas: seat hold system, fare consistency, navigation/UX fixes, and duplicate prevention.

---

## Area 1: Seat Hold System

### Problem
Seats are currently reduced only when a driver approves a booking. This allows multiple riders to request the last available seat simultaneously, causing the driver to manually reject all but one.

### Design
- At booking creation (`POST /bookings`), immediately decrement `seats_available` on the trip.
- Add a `hold_expires_at TIMESTAMPTZ` column to the `bookings` table.
- `hold_expires_at = MIN(NOW() + INTERVAL '2 hours', departure_time - INTERVAL '1 hour')`
- A pg_cron job runs every 5 minutes: finds pending bookings where `hold_expires_at < NOW()`, sets their `booking_state` to `rejected`, and restores `seats_available`.
- As a safety net, the booking fetch endpoint also checks expiry lazily and expires on read.
- When a rider cancels a **pending** booking, restore the seat immediately (currently only done for confirmed cancellations).
- When a driver approves a booking, clear `hold_expires_at` (seat is now permanently held).

### Migration
New migration `024_seat_hold_system.sql`:
```sql
ALTER TABLE bookings ADD COLUMN hold_expires_at TIMESTAMPTZ;
-- Backfill: set hold_expires_at for existing pending bookings
UPDATE bookings SET hold_expires_at = created_at + INTERVAL '2 hours'
WHERE booking_state = 'pending' AND hold_expires_at IS NULL;
-- pg_cron job
SELECT cron.schedule('expire-pending-bookings', '*/5 * * * *', $$
  WITH expired AS (
    UPDATE bookings
    SET booking_state = 'rejected'
    WHERE booking_state = 'pending' AND hold_expires_at < NOW()
    RETURNING trip_id, seats_booked
  )
  UPDATE trips t
  SET seats_available = seats_available + e.seats_booked
  FROM expired e
  WHERE t.trip_id = e.trip_id;
$$);
```

---

## Area 2: Fare Consistency

### Problem
- `RiderSearchResultsView` shows `perRiderSplit ?? estimatedCost`
- `TripDetailView` sometimes shows hardcoded mock values ($5, $3.50, $1.50)
- `BookingListView` trip card shows a price inconsistent with the booking quote
- `DriverTripDetailsView` hardcodes `$8.50 * seats` instead of using actual quotes

### Design
**Source of truth:** `max_price` from the `quotes` table, stored at booking creation. For pre-booking display (search results, trip detail before booking), use `costBreakdown.perRiderSplit` from the trip search response.

**iOS changes:**
- `TripDetailView`: Remove all hardcoded mock pricing. Show `costBreakdown.perRiderSplit` before booking, and `booking.quote.maxPrice` after booking exists.
- `BookingListView` / `BookingRow`: Display fare from `booking.quote.maxPrice` (fetched as part of booking response).
- `DriverTripDetailsView`: Per-rider fare comes from each `BookingWithRider`'s `scostBreakdown.total`. Total trip earnings = sum of all confirmed/approved riders' fares. Show both on the trip card.
- `RiderSearchResultsView`: Already correct; keep using `perRiderSplit ?? estimatedCost`.

**Backend changes:**
- Ensure `GET /bookings/trip/:tripId` and `GET /bookings` responses include the quote `max_price` as a `fare` field on each booking.
- `BookingWithRider` model returned to driver must include each rider's fare.

---

## Area 3: Navigation & UX Fixes

### 3a. Post-Request Navigation
**Problem:** After tapping "Request Ride", the rider sees chat but the booking isn't visible in the trips tab and TripDetailView isn't opened for the new booking.

**Design:**
- After `requestBooking()` succeeds in `TripDetailViewModel`, post `NavigateToBookingsTab` notification (already done) AND post a new `OpenBookingDetail` notification with the new `bookingId`.
- `BookingListView` listens for `OpenBookingDetail` and pushes `TripDetailView` for that booking onto its navigation stack.
- Dismiss the search results sheet before navigating.

### 3b. Trip History Filter
**Problem:** Profile `TripHistoryView` shows all trips with no date filter.

**Design:**
- Filter bookings/trips to only show those where the trip's `departure_time` is more than 24 hours in the past.
- Condition: `departure_time < NOW() - INTERVAL '24 hours'` (backend) or `trip.departureTime < Date.now() - 86400000` (iOS).
- Apply same filter to both rider trip history and driver trip history in `ProfileView`.

### 3c. Delete Cancelled Bookings/Trips
**Problem:** No way to remove cancelled entries from lists.

**Design:**
- **Rider:** In `BookingListView`, add swipe-to-delete on cancelled booking rows. Calls new `DELETE /bookings/:id` endpoint (soft delete: sets `deleted_at`, hides from queries).
- **Driver:** In posted trips list, add delete option for cancelled trips. Calls existing or new `DELETE /trips/:id` endpoint (soft delete).
- iOS: use `.onDelete` modifier or swipe action on the list row. Show confirmation alert before deletion.

---

## Area 4: Duplicate Prevention

### 4a. Duplicate Booking (Rider)
**Backend:** Already enforced — unique index `uq_active_booking_trip_rider` prevents two active bookings for the same rider+trip. Cancelled/rejected bookings are excluded from the constraint, so re-requesting after cancellation is allowed.

**iOS fix needed:** `TripDetailViewModel.checkExistingBooking()` currently loads any existing booking and shows its state. If the existing booking is `cancelled` or `rejected`, the view must clear that state and allow a fresh request. Currently the "Request Ride" button may remain disabled or show stale state.

Fix: In `checkExistingBooking()`, if `existingBooking.bookingState == .cancelled || .rejected`, set `self.booking = nil` and `self.bookingState = nil`.

### 4b. Duplicate Trip Posting (Driver)
**Backend:** `checkTripOverlap()` already blocks time-overlapping trips. Two additional guards:
1. Verify cancelled trips are excluded from the overlap check so drivers can re-post on the same route after cancelling.
2. Add an idempotency check: if a driver posts the exact same origin + destination + departure_time, return a 409 rather than creating a duplicate entry.

**iOS fix needed:** `CreateTripView` must surface the 409/conflict error from the API as a user-facing alert with the server message. Disable the submit button after first tap to prevent double-submission.

---

## Verification

1. **Seat hold:** Request a ride, verify `seats_available` decrements. Wait (or manually expire `hold_expires_at`), verify seat restores. Cancel a pending booking, verify seat restores immediately.
2. **Fare consistency:** Book a trip and verify the fare shown in search results, detail view, and trips tab all match the `max_price` from the quotes table.
3. **Post-request navigation:** Tap Request Ride → verify trips tab opens and TripDetailView shows for the new pending booking.
4. **Trip history:** Verify only trips departed >24 hours ago appear in profile history.
5. **Delete:** Swipe-delete a cancelled booking → verify it disappears. Attempt same booking again → allowed.
6. **Duplicate booking:** Request same trip twice without cancelling → second request returns existing booking, no error. Cancel then re-request → allowed.
7. **Duplicate trip:** Driver posts overlapping trip → clear error shown.
