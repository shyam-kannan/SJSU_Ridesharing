# Driver/Rider UX, Payment & Stats Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix multi-rider trip grouping, remove redundant driver home section, add real Stripe payment confirmation for riders, add Stripe Connect payout onboarding for drivers, show per-trip payout totals, and fix incorrect stats in driver/rider profiles.

**Architecture:** Seven independent tasks grouped by backend-first ordering. Backend stat fixes and new Stripe Connect endpoint come first, then iOS UI changes, then Stripe SDK integration last (requires Xcode SPM). Each task is independently committable and testable.

**Tech Stack:** Swift/SwiftUI (iOS), TypeScript/Node.js (backend), PostgreSQL/Supabase, Stripe API (server-side), Stripe iOS SDK via Swift Package Manager.

---

## File Map

### Backend
- **Modify:** `services/user-service/src/services/user.service.ts` — fix stat queries, add Stripe Connect helpers
- **Modify:** `services/user-service/src/routes/user.routes.ts` — add `/driver/stripe-onboard` endpoint
- **Modify:** `services/user-service/src/controllers/user.controller.ts` — add stripe onboard controller
- **Modify:** `services/trip-service/src/services/trip.service.ts` — add payout aggregates to trip list response
- **Create:** `shared/database/migrations/20260507000001_add_stripe_connect.js` — adds `stripe_connect_account_id` column

### iOS
- **Modify:** `LessGo/LessGo/Core/Home/Views/DriverHomeView.swift` — remove `postedRidesSection`
- **Modify:** `LessGo/LessGo/Core/Booking/Views/BookingConfirmationView.swift` — group bookings by trip in Passengers tab, add payout display to PostedTripRow, add Payout card in BookingListView
- **Modify:** `LessGo/LessGo/Core/Booking/ViewModels/BookingViewModel.swift` — add `groupedByTrip` computed property
- **Modify:** `LessGo/LessGo/Models/Trip.swift` — add `totalPayout` and `totalQuoted` fields
- **Modify:** `LessGo/LessGo/Models/User.swift` — add `stripeConnectAccountId` field
- **Modify:** `LessGo/LessGo/Services/UserService.swift` — add `startStripeOnboarding()` method
- **Modify:** `LessGo/LessGo/Core/Profile/Views/ProfileView.swift` — add Payout Setup card in driver dashboard
- **Modify:** `LessGo/LessGo/Core/Authentication/Views/DriverSetupView.swift` (or wherever driver setup ends) — trigger payout onboarding after setup
- **Modify:** `LessGo/LessGo/Core/Rider/ViewModels/TripDetailViewModel.swift` — call Stripe SDK after getting clientSecret
- **Modify:** `LessGo/LessGo/App/LessGoApp.swift` — initialize Stripe SDK with publishable key

---

## Task 1: Fix Backend Profile Stats Queries

**Files:**
- Modify: `services/user-service/src/services/user.service.ts` (lines 238–261)

**Problem:** `total_trips_as_driver` counts all trips regardless of status. `total_bookings_as_rider` counts all bookings regardless of status. Both should count only completed records.

- [ ] **Step 1: Fix `total_trips_as_driver` to count only completed trips**

In `services/user-service/src/services/user.service.ts`, find the block around line 240 that reads:
```typescript
const tripStatsQuery = `
  SELECT COUNT(*) as total_trips
  FROM trips
  WHERE driver_id = $1
`;
```
Replace with:
```typescript
const tripStatsQuery = `
  SELECT COUNT(*) as total_trips
  FROM trips
  WHERE driver_id = $1 AND status = 'completed'
`;
```

- [ ] **Step 2: Fix `total_bookings_as_rider` to count only completed bookings**

In the same file around line 251–255, find:
```typescript
const bookingStatsQuery = `
  SELECT COUNT(*) as total_bookings
  FROM bookings
  WHERE rider_id = $1
`;
```
Replace with:
```typescript
const bookingStatsQuery = `
  SELECT COUNT(*) as total_bookings
  FROM bookings
  WHERE rider_id = $1
    AND status = 'completed'
`;
```

- [ ] **Step 3: Verify the queries against the database**

Run this SQL in the Supabase SQL editor (project `bdefyxdpojqxxvaybfwk`) to confirm the fix:
```sql
-- Check a known driver's trip count per status
SELECT status, COUNT(*) 
FROM trips 
WHERE driver_id = '<a known driver user_id>'
GROUP BY status;

-- The new query should return only the 'completed' row count
SELECT COUNT(*) as total_trips
FROM trips
WHERE driver_id = '<a known driver user_id>' AND status = 'completed';
```

- [ ] **Step 4: Commit**

```bash
git add services/user-service/src/services/user.service.ts
git commit -m "fix: count only completed trips/bookings in profile stats"
```

---

## Task 2: Add Payout Aggregates to Trip List Response

Show per-trip `totalPayout` (sum of captured payments) and `totalQuoted` (sum of approved-but-uncaptured quote prices) on driver trip cards.

**Files:**
- Modify: `services/trip-service/src/services/trip.service.ts`
- Modify: `LessGo/LessGo/Models/Trip.swift`
- Modify: `LessGo/LessGo/Core/Booking/Views/BookingConfirmationView.swift` (PostedTripRow)

- [ ] **Step 1: Add payment aggregates to the trip list query**

In `services/trip-service/src/services/trip.service.ts`, find the query that returns trips for a driver (look for the function that handles `driverId` filtering — likely `listTrips` or similar). Add a LEFT JOIN to aggregate payment data.

Find the SELECT that returns trip rows and add these two aggregate fields:

```typescript
// Add after existing SELECT columns, inside the trips list query:
COALESCE((
  SELECT SUM(p.amount)
  FROM payments p
  JOIN bookings b ON p.booking_id = b.booking_id
  WHERE b.trip_id = t.trip_id AND p.status = 'captured'
), 0) AS total_payout,
COALESCE((
  SELECT SUM(q.max_price)
  FROM quotes q
  JOIN bookings b ON q.booking_id = b.booking_id
  WHERE b.trip_id = t.trip_id
    AND b.booking_state = 'approved'
    AND NOT EXISTS (
      SELECT 1 FROM payments p2
      WHERE p2.booking_id = b.booking_id AND p2.status = 'captured'
    )
), 0) AS total_quoted
```

Ensure these fields are included in the return object:
```typescript
return {
  // ... existing fields ...
  total_payout: parseFloat(row.total_payout || '0'),
  total_quoted: parseFloat(row.total_quoted || '0'),
};
```

- [ ] **Step 2: Add fields to iOS Trip model**

In `LessGo/LessGo/Models/Trip.swift`, add two optional fields to the `Trip` struct:

```swift
let totalPayout: Double?
let totalQuoted: Double?
```

Add to the `CodingKeys` enum:
```swift
case totalPayout = "total_payout"
case totalQuoted = "total_quoted"
```

- [ ] **Step 3: Update PostedTripRow to show payout info**

In `LessGo/LessGo/Core/Booking/Views/BookingConfirmationView.swift`, find `PostedTripRow` (around line 844). Inside its `body`, after the existing `HStack(spacing: 16)` that shows clock and seats (around line 877), add:

```swift
// Payout summary — only show if either amount is non-zero
let payout = trip.totalPayout ?? 0
let quoted = trip.totalQuoted ?? 0
if payout > 0 || quoted > 0 {
    HStack(spacing: 12) {
        if payout > 0 {
            Label(String(format: "$%.2f payout", payout), systemImage: "dollarsign.circle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.brandGreen)
        }
        if quoted > 0 {
            Label(String(format: "$%.2f quoted", quoted), systemImage: "clock.fill")
                .font(.system(size: 12))
                .foregroundColor(.brandOrange)
        }
    }
}
```

- [ ] **Step 4: Build and verify in Xcode simulator**

Run the app as a driver, go to Trips tab → Posted Trips. Confirm trip cards with riders show payout/quoted amounts. Trips with no riders show nothing.

- [ ] **Step 5: Commit**

```bash
git add services/trip-service/src/services/trip.service.ts \
        LessGo/LessGo/Models/Trip.swift \
        LessGo/LessGo/Core/Booking/Views/BookingConfirmationView.swift
git commit -m "feat: show per-trip payout and quoted amounts on driver trip cards"
```

---

## Task 3: Remove Posted Rides Section from DriverHomeView

**Files:**
- Modify: `LessGo/LessGo/Core/Home/Views/DriverHomeView.swift`

The `postedRidesSection` (with Passengers/Posted Trips tabs) duplicates what the Trips tab already shows. Remove it entirely. The driver home becomes: map + availability toggle + Post Ride button.

- [ ] **Step 1: Remove the state variables used only by postedRidesSection**

In `DriverHomeView.swift`, find and delete these `@State` declarations:
```swift
@State private var selectedDriverTab: Int = 0
@State private var showDeleteTripConfirm: Bool = false
@State private var tripPendingDelete: Trip? = nil
@State private var selectedTripForDetail: Trip? = nil
```

Only delete them if they are **exclusively** used by `postedRidesSection` and `passengersTabContent`/`postedTripsTabContent`. Search with Xcode for each symbol before deleting.

- [ ] **Step 2: Remove postedRidesSection and its child views**

Delete the following private computed properties from `DriverHomeView`:
- `var postedRidesSection: some View` (around line 546)
- `var passengersTabContent: some View` (around line 579)
- `var postedTripsTabContent: some View` (around line 656)
- `var tripsWithPassengers: [Trip]` (around line 539)
- `var scheduledTrips: [Trip]` (around line 527)
- `var cancelledTrips: [Trip]` (around line 532)
- `var completedTrips: [Trip]` (around line 536)

- [ ] **Step 3: Remove the reference to postedRidesSection in the body**

Search for `postedRidesSection` in the `body` property (around line 72) and delete the line that calls it (along with any surrounding spacing/padding modifiers that were added solely for it).

Also remove the `.sheet(item: $selectedTripForDetail)` modifier (around line 224) if it only served the removed section.

- [ ] **Step 4: Remove the .fullScreenCover for showIncomingRequest if needed, and remove profileVM.driverTrips fetch if only used here**

Check whether `profileVM.driverTrips` is still used elsewhere in `DriverHomeView`. If it is only used by the removed section, remove the `Task { await profileVM.fetchDriverTrips() }` call too. Leave it if used by anything else (e.g., availability toggle logic).

- [ ] **Step 5: Build and verify**

Build in Xcode (Cmd+B). Fix any "use of unresolved identifier" errors from the removed state. Run in simulator as driver and confirm home screen shows only the map, availability toggle, and Post a Ride button.

- [ ] **Step 6: Commit**

```bash
git add LessGo/LessGo/Core/Home/Views/DriverHomeView.swift
git commit -m "feat: remove redundant Posted Rides section from driver home"
```

---

## Task 4: Group Bookings by Trip in Passengers Tab

**Files:**
- Modify: `LessGo/LessGo/Core/Booking/ViewModels/BookingViewModel.swift`
- Modify: `LessGo/LessGo/Core/Booking/Views/BookingConfirmationView.swift`

When a driver views the Passengers tab, two riders booking the same trip show as two rows. Fix: group bookings by `trip_id` and render one trip card per trip.

- [ ] **Step 1: Add a grouped-by-trip computed property to BookingViewModel**

In `LessGo/LessGo/Core/Booking/ViewModels/BookingViewModel.swift`, add:

```swift
/// Groups driver-view bookings by trip_id, preserving the most-recent booking order.
var bookingsGroupedByTrip: [(trip: Trip, bookings: [Booking])] {
    var seen = Set<String>()
    var groups: [(trip: Trip, bookings: [Booking])] = []
    for booking in bookings {
        guard let trip = booking.trip else { continue }
        if seen.contains(trip.id) {
            if let idx = groups.firstIndex(where: { $0.trip.id == trip.id }) {
                groups[idx].bookings.append(booking)
            }
        } else {
            seen.insert(trip.id)
            groups.append((trip: trip, bookings: [booking]))
        }
    }
    return groups
}
```

- [ ] **Step 2: Replace the Passengers tab ForEach with grouped trip cards**

In `LessGo/LessGo/Core/Booking/Views/BookingConfirmationView.swift`, find the driver passengers ForEach (around line 554 inside the `showAsDriver` path):

```swift
ForEach(filteredBookings) { booking in
    BookingRow(booking: booking, ...)
        .padding(.horizontal, AppConstants.pagePadding)
}
```

Replace with:

```swift
ForEach(vm.bookingsGroupedByTrip, id: \.trip.id) { group in
    DriverTripGroupRow(trip: group.trip, bookings: group.bookings, vm: vm)
        .padding(.horizontal, AppConstants.pagePadding)
}
```

- [ ] **Step 3: Add DriverTripGroupRow view**

Add a new private struct to `BookingConfirmationView.swift` (after `PostedTripRow`):

```swift
private struct DriverTripGroupRow: View {
    let trip: Trip
    let bookings: [Booking]
    let vm: BookingViewModel
    @State private var showDetail = false

    private var pendingCount: Int {
        bookings.filter { $0.bookingState == .pending }.count
    }
    private var approvedCount: Int {
        bookings.filter { $0.bookingState == .approved }.count
    }
    private var riderNames: String {
        bookings.compactMap { $0.rider?.name.components(separatedBy: " ").first }
                .joined(separator: ", ")
    }

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(trip.origin) → \(trip.destination)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        Text(trip.departureTime, format: .dateTime.month().day().hour().minute())
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textTertiary)
                }
                HStack(spacing: 8) {
                    if pendingCount > 0 {
                        Label("\(pendingCount) pending", systemImage: "clock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    if approvedCount > 0 {
                        Label("\(approvedCount) confirmed", systemImage: "person.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.brandGreen)
                            .clipShape(Capsule())
                    }
                }
                if !riderNames.isEmpty {
                    Text(riderNames)
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(AppConstants.cardPadding)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardRadius, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            DriverTripDetailsView(trip: trip)
        }
    }
}
```

- [ ] **Step 4: Keep the filteredBookings path for riders unchanged**

The `filteredBookings` ForEach with `BookingRow` is for riders (`!showAsDriver`). Ensure the grouping only applies to the driver Passengers tab path. Check that `else if showAsDriver && driverTab == .postedTrips` and the rider path remain untouched.

- [ ] **Step 5: Build and verify in simulator**

Log in as a driver. Go to Trips tab → Passengers. With 2 riders booked on the same trip, confirm one group card shows with "2 pending" badge and both rider names. Tapping opens `DriverTripDetailsView`.

- [ ] **Step 6: Commit**

```bash
git add LessGo/LessGo/Core/Booking/ViewModels/BookingViewModel.swift \
        LessGo/LessGo/Core/Booking/Views/BookingConfirmationView.swift
git commit -m "feat: group driver passenger bookings by trip in Trips tab"
```

---

## Task 5: DB Migration + Backend Stripe Connect Endpoint

**Files:**
- Create: `shared/database/migrations/20260507000001_add_stripe_connect.js`
- Modify: `services/user-service/src/services/user.service.ts`
- Modify: `services/user-service/src/controllers/user.controller.ts`
- Modify: `services/user-service/src/routes/user.routes.ts`

- [ ] **Step 1: Create the migration file**

Create `shared/database/migrations/20260507000001_add_stripe_connect.js`:

```javascript
exports.up = async (knex) => {
  await knex.schema.table('users', (table) => {
    table.string('stripe_connect_account_id').nullable();
  });
};

exports.down = async (knex) => {
  await knex.schema.table('users', (table) => {
    table.dropColumn('stripe_connect_account_id');
  });
};
```

- [ ] **Step 2: Run the migration**

```bash
npm run bootstrap:db
```

Expected: migration applies without error. Verify in Supabase dashboard that `users` table now has a `stripe_connect_account_id` column.

- [ ] **Step 3: Add Stripe Connect service functions**

In `services/user-service/src/services/user.service.ts`, add at the bottom:

```typescript
import Stripe from 'stripe';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2023-10-16' });

export const createStripeConnectOnboardingUrl = async (
  userId: string,
  returnUrl: string,
  refreshUrl: string
): Promise<{ url: string; accountId: string }> => {
  const user = await getUserById(userId);
  if (!user) throw new Error('User not found');

  // Reuse existing account if already created
  let accountId = user.stripe_connect_account_id as string | null;
  if (!accountId) {
    const account = await stripe.accounts.create({
      type: 'express',
      email: user.email,
      metadata: { userId },
    });
    accountId = account.id;
    await pool.query(
      'UPDATE users SET stripe_connect_account_id = $1 WHERE user_id = $2',
      [accountId, userId]
    );
  }

  const accountLink = await stripe.accountLinks.create({
    account: accountId,
    refresh_url: refreshUrl,
    return_url: returnUrl,
    type: 'account_onboarding',
  });

  return { url: accountLink.url, accountId };
};

export const getStripeConnectDashboardUrl = async (userId: string): Promise<string> => {
  const user = await getUserById(userId);
  if (!user?.stripe_connect_account_id) throw new Error('No Stripe account found');
  const loginLink = await stripe.accounts.createLoginLink(user.stripe_connect_account_id as string);
  return loginLink.url;
};
```

- [ ] **Step 4: Add controller methods**

In `services/user-service/src/controllers/user.controller.ts`, add:

```typescript
export const stripeOnboard = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;
    const returnUrl = `${process.env.APP_SCHEME ?? 'lessgo'}://stripe-return`;
    const refreshUrl = `${process.env.APP_SCHEME ?? 'lessgo'}://stripe-refresh`;
    const result = await userService.createStripeConnectOnboardingUrl(userId, returnUrl, refreshUrl);
    res.json({ status: 'success', data: result });
  } catch (err) {
    next(err);
  }
};

export const stripeDashboard = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;
    const url = await userService.getStripeConnectDashboardUrl(userId);
    res.json({ status: 'success', data: { url } });
  } catch (err) {
    next(err);
  }
};
```

- [ ] **Step 5: Register routes**

In `services/user-service/src/routes/user.routes.ts`, add two new authenticated routes:

```typescript
router.post('/driver/stripe-onboard', authenticate, stripeOnboard);
router.get('/driver/stripe-dashboard', authenticate, stripeDashboard);
```

Import `stripeOnboard` and `stripeDashboard` from the controller at the top of the file.

- [ ] **Step 6: Verify the endpoint**

Start the user service and hit the endpoint:
```bash
curl -X POST http://localhost:3002/users/driver/stripe-onboard \
  -H "Authorization: Bearer <driver_jwt_token>"
```
Expected: `{ "status": "success", "data": { "url": "https://connect.stripe.com/...", "accountId": "acct_..." } }`

- [ ] **Step 7: Commit**

```bash
git add shared/database/migrations/20260507000001_add_stripe_connect.js \
        services/user-service/src/services/user.service.ts \
        services/user-service/src/controllers/user.controller.ts \
        services/user-service/src/routes/user.routes.ts
git commit -m "feat: add Stripe Connect onboarding endpoint and DB column"
```

---

## Task 6: iOS Driver Stripe Connect Onboarding

**Files:**
- Modify: `LessGo/LessGo/Models/User.swift` — add `stripeConnectAccountId`
- Modify: `LessGo/LessGo/Services/UserService.swift` — add `startStripeOnboarding()` and `getStripeDashboardUrl()`
- Modify: `LessGo/LessGo/Core/Profile/Views/ProfileView.swift` — add Payout Setup card
- Modify: the view that shows after driver profile setup completes (search for `showDriverSetup = false` or the sheet dismiss in ProfileView) — trigger onboarding

- [ ] **Step 1: Add stripeConnectAccountId to User model**

In `LessGo/LessGo/Models/User.swift`, add to the `User` struct:

```swift
let stripeConnectAccountId: String?
```

Add to `CodingKeys`:
```swift
case stripeConnectAccountId = "stripe_connect_account_id"
```

- [ ] **Step 2: Add service methods**

In `LessGo/LessGo/Services/UserService.swift`, add:

```swift
func startStripeOnboarding() async throws -> URL {
    struct OnboardResponse: Codable {
        let status: String
        let data: OnboardData
        struct OnboardData: Codable {
            let url: String
        }
    }
    let response: OnboardResponse = try await network.request(
        endpoint: "/users/driver/stripe-onboard",
        method: .post
    )
    guard let url = URL(string: response.data.url) else {
        throw NetworkError.decodingError
    }
    return url
}

func getStripeDashboardUrl() async throws -> URL {
    struct DashResponse: Codable {
        let status: String
        let data: DashData
        struct DashData: Codable {
            let url: String
        }
    }
    let response: DashResponse = try await network.request(
        endpoint: "/users/driver/stripe-dashboard",
        method: .get
    )
    guard let url = URL(string: response.data.url) else {
        throw NetworkError.decodingError
    }
    return url
}
```

- [ ] **Step 3: Add Payout Setup card to ProfileView driver dashboard**

In `LessGo/LessGo/Core/Profile/Views/ProfileView.swift`, find `driverVehicleSection` (around line 574). Add a new `@State` at the top of `ProfileView`:

```swift
@State private var showStripeOnboarding = false
@State private var stripeOnboardingURL: URL? = nil
```

After the Vehicle Info card block (around line 690), add a Payout Setup card:

```swift
// Payout Setup Card
let hasStripeAccount = authVM.currentUser?.stripeConnectAccountId != nil
VStack(spacing: 0) {
    HStack(spacing: 14) {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill((hasStripeAccount ? Color.brandGreen : Color.brandOrange).opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: hasStripeAccount ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(hasStripeAccount ? .brandGreen : .brandOrange)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Payout Setup")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text(hasStripeAccount ? "Bank account connected" : "Required to receive payments")
                .font(.system(size: 13))
                .foregroundColor(hasStripeAccount ? .brandGreen : .brandOrange)
        }
        Spacer()
        Button(hasStripeAccount ? "Edit" : "Setup") {
            Task {
                do {
                    let url = hasStripeAccount
                        ? try await UserService.shared.getStripeDashboardUrl()
                        : try await UserService.shared.startStripeOnboarding()
                    stripeOnboardingURL = url
                    showStripeOnboarding = true
                } catch {
                    // Surface error via existing error handling pattern
                }
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(hasStripeAccount ? .brand : .brandOrange)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background((hasStripeAccount ? Color.brand : Color.brandOrange).opacity(0.1))
        .cornerRadius(10)
    }
    .padding(AppConstants.cardPadding)
}
.background(
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.panelGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder((hasStripeAccount ? Color.brandGreen : Color.brandOrange).opacity(0.2), lineWidth: 1)
        )
)
.shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
.padding(.horizontal, AppConstants.pagePadding)
```

- [ ] **Step 4: Add Safari sheet for Stripe onboarding URL**

In `ProfileView.swift`, find where the existing sheets are declared (`.sheet(isPresented:)` calls). Add:

```swift
.sheet(isPresented: $showStripeOnboarding, onDismiss: {
    // Refresh user profile on return to pick up updated stripe_connect_account_id
    Task { await authVM.refreshCurrentUser() }
}) {
    if let url = stripeOnboardingURL {
        SafariView(url: url)
    }
}
```

- [ ] **Step 5: Add SafariView helper (if not already present)**

Search the codebase for `SafariView`. If not found, create `LessGo/LessGo/Utils/SafariView.swift`:

```swift
import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
```

- [ ] **Step 6: Trigger onboarding after driver profile setup completes**

Find where driver setup completes in the app — look for `showDriverSetup = false` in `ProfileView.swift` (around line 219). In the `onDismiss` callback of the driver setup sheet, after the existing refresh call, trigger onboarding if `stripeConnectAccountId` is nil:

```swift
.sheet(isPresented: $showDriverSetup, onDismiss: {
    Task {
        await authVM.refreshCurrentUser()
        // Prompt payout setup for newly registered drivers
        if authVM.isDriver && authVM.currentUser?.stripeConnectAccountId == nil {
            do {
                let url = try await UserService.shared.startStripeOnboarding()
                stripeOnboardingURL = url
                showStripeOnboarding = true
            } catch {}
        }
    }
}) { ... }
```

- [ ] **Step 7: Build and verify**

Run in simulator as a driver without `stripe_connect_account_id`:
- Profile tab → Driver Dashboard shows orange "Payout Setup / Required to receive payments" card
- Tap "Setup" → Safari opens Stripe onboarding URL
- After returning, card refreshes to green "Bank account connected"

- [ ] **Step 8: Commit**

```bash
git add LessGo/LessGo/Models/User.swift \
        LessGo/LessGo/Services/UserService.swift \
        LessGo/LessGo/Core/Profile/Views/ProfileView.swift \
        LessGo/LessGo/Utils/SafariView.swift
git commit -m "feat: Stripe Connect payout onboarding for drivers (profile card + post-setup trigger)"
```

---

## Task 7: Fix Rider Payment Button (Stripe iOS SDK)

**Files:**
- Modify: `LessGo/LessGo/App/LessGoApp.swift` — initialize Stripe SDK
- Modify: `LessGo/LessGo/Core/Rider/ViewModels/TripDetailViewModel.swift` — use Stripe SDK
- Modify: `LessGo/LessGo/Utils/Constants.swift` — ensure publishable key is set

**Note:** The Stripe iOS SDK is not yet in this project. Add it via Swift Package Manager in Xcode before writing any code.

- [ ] **Step 1: Add Stripe iOS SDK via Swift Package Manager**

In Xcode: File → Add Package Dependencies → enter URL `https://github.com/stripe/stripe-ios` → set version rule to "Up to Next Major" from `23.0.0` → Add `StripePaymentsUI` and `StripeCore` to the `LessGo` target.

- [ ] **Step 2: Set real Stripe publishable key**

In `LessGo/LessGo/Utils/Constants.swift`, replace the placeholder:
```swift
enum StripeConfig {
    static let publishableKey = "pk_test_YOUR_STRIPE_PUBLISHABLE_KEY"
}
```
With the actual test key from the Stripe dashboard (starts with `pk_test_`).

- [ ] **Step 3: Initialize Stripe at app launch**

In `LessGo/LessGo/App/LessGoApp.swift`, add import and initialization:

```swift
import StripeCore

@main
struct LessGoApp: App {
    init() {
        StripeAPI.defaultPublishableKey = StripeConfig.publishableKey
    }
    // ... existing body
}
```

- [ ] **Step 4: Update BookingService to return clientSecret**

In `LessGo/LessGo/Services/BookingService.swift`, find `authorizePayment` (around line 137). Change the return type from `[String: Any]` to a typed struct so the caller can access `clientSecret`:

```swift
struct AuthorizeResult {
    let clientSecret: String
    let paymentIntentId: String
}

func authorizePayment(bookingId: String) async throws -> AuthorizeResult {
    struct AuthorizePaymentResponse: Codable {
        let status: String
        let data: AuthorizePaymentData?
        struct AuthorizePaymentData: Codable {
            let clientSecret: String
            let paymentIntentId: String
        }
    }

    let response: AuthorizePaymentResponse = try await network.request(
        endpoint: "/bookings/\(bookingId)/authorize-payment",
        method: .post
    )

    guard let data = response.data else {
        throw NetworkError.serverError(APIError(status: "error", message: "No payment data returned", errors: nil))
    }

    return AuthorizeResult(clientSecret: data.clientSecret, paymentIntentId: data.paymentIntentId)
}
```

- [ ] **Step 5: Update TripDetailViewModel to confirm payment with Stripe SDK**

In `LessGo/LessGo/Core/Rider/ViewModels/TripDetailViewModel.swift`, add import at top:

```swift
import StripePaymentsUI
```

Replace the `authorizePayment()` function:

```swift
@MainActor
func authorizePayment(from viewController: UIViewController) async {
    guard let bookingId = booking?.id else { return }
    isAuthorizing = true
    errorMessage = nil
    defer { isAuthorizing = false }

    do {
        let result = try await bookingService.authorizePayment(bookingId: bookingId)

        // Confirm the PaymentIntent with Stripe SDK
        let paymentIntentParams = STPPaymentIntentParams(clientSecret: result.clientSecret)
        paymentIntentParams.paymentMethodParams = STPPaymentMethodParams(
            card: STPPaymentMethodCardParams(),
            billingDetails: nil,
            metadata: nil
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            STPPaymentHandler.shared().confirmPayment(paymentIntentParams, with: viewController) { status, _, error in
                switch status {
                case .succeeded:
                    continuation.resume()
                case .canceled:
                    continuation.resume(throwing: NetworkError.cancelled)
                case .failed:
                    continuation.resume(throwing: error ?? NetworkError.unknown)
                @unknown default:
                    continuation.resume(throwing: NetworkError.unknown)
                }
            }
        }

        paymentAuthorized = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    } catch let error as NetworkError where error == .cancelled {
        // User cancelled — no error message
    } catch let error as NetworkError {
        errorMessage = error.userMessage
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    } catch {
        errorMessage = "Payment failed. Please try again."
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
```

- [ ] **Step 6: Update TripDetailView to pass UIViewController**

In `LessGo/LessGo/Core/Rider/Views/TripDetailView.swift`, find the "Confirm & Pay" button action (around line 611). The view needs a `UIViewController` reference for Stripe. Add this in the view:

```swift
// Near the button:
Button(action: {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController else { return }
    Task { await viewModel.authorizePayment(from: rootVC) }
}) {
    // ... existing button label unchanged
}
```

- [ ] **Step 7: Add NetworkError.cancelled case if missing**

Search `NetworkError` enum in `LessGo/LessGo/Networking/NetworkError.swift` (or similar). If `.cancelled` doesn't exist, add:
```swift
case cancelled
```
Also add `Equatable` conformance or an explicit `==` if needed for the catch clause.

- [ ] **Step 8: Build and run**

Build in Xcode. Run in simulator as a rider with an approved booking. Tap "Confirm & Pay". Stripe's payment sheet should appear. Use test card `4242 4242 4242 4242`, any future date, any CVC. Payment should succeed and `paymentAuthorized` should become `true`.

- [ ] **Step 9: Commit**

```bash
git add LessGo/LessGo/App/LessGoApp.swift \
        LessGo/LessGo/Utils/Constants.swift \
        LessGo/LessGo/Services/BookingService.swift \
        LessGo/LessGo/Core/Rider/ViewModels/TripDetailViewModel.swift \
        LessGo/LessGo/Core/Rider/Views/TripDetailView.swift
git commit -m "feat: complete Stripe payment confirmation in rider TripDetailView"
```

---

## Verification Checklist

After all tasks complete, run through these end-to-end scenarios:

**Driver stats:**
- [ ] Driver with 0 completed / 2 pending / 2 cancelled trips → Trips stat shows `0`

**Rider stats:**
- [ ] Rider with 1 completed + 2 cancelled bookings → Bookings stat shows `1`

**Multi-rider grouping:**
- [ ] Two riders book the same trip → driver Trips tab Passengers shows **one** group card with "2 pending" badge and both names
- [ ] Tapping group card opens `DriverTripDetailsView` with both riders listed

**Driver home:**
- [ ] No "Your Posted Rides" section on driver home screen
- [ ] Trips tab still shows Posted Trips tab with all posted trips

**Trip card payout:**
- [ ] Rider A pays $5 (captured), Rider B quoted $6 (approved, not yet paid) → PostedTripRow shows "$5.00 payout · $6.00 quoted"

**Driver Stripe Connect:**
- [ ] New driver completing profile setup → Safari opens Stripe onboarding
- [ ] Existing driver without payout → Profile shows orange warning card "Required to receive payments" with Setup button
- [ ] After onboarding → card turns green "Bank account connected"

**Rider payment:**
- [ ] Booking approved → "Confirm & Pay" button active
- [ ] Tapping → Stripe PaymentSheet appears
- [ ] Paying with test card `4242 4242 4242 4242` → payment succeeds, button disappears
