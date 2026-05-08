import express, { Application } from 'express';
import cors from 'cors';
import axios from 'axios';

const app: Application = express();
app.use(express.json());
app.use(cors());

// ── Configuration ─────────────────────────────────────────────────────────────
const IRS_MILEAGE_RATE = 0.67;   // $/mile — covers fuel + wear + depreciation
const DRIVER_HOURLY    = 15.00;  // $/hr  — driver time compensation
const DETOUR_SURCHARGE = 1.25;   // 25% premium on rerouting miles

const ROUTING_SERVICE_URL = process.env.ROUTING_SERVICE_URL || 'http://127.0.0.1:8002';
const TRIP_SERVICE_URL    = process.env.TRIP_SERVICE_URL    || 'http://127.0.0.1:3003';
const BOOKING_SERVICE_URL = process.env.BOOKING_SERVICE_URL || 'http://127.0.0.1:3004';

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({
    status: 'success',
    message: 'Cost Calculation Service is running',
    service: 'cost-calculation-service',
    timestamp: new Date().toISOString(),
  });
});

// ── POST /cost/calculate ──────────────────────────────────────────────────────
// Simple shared-cost estimate (no per-rider detour, used at booking time).
app.post('/cost/calculate', async (req, res) => {
  try {
    const { origin, destination, num_riders } = req.body;

    if (!origin || !destination || !num_riders) {
      res.status(400).json({
        status: 'error',
        message: 'origin, destination, and num_riders are required',
      });
      return;
    }

    let distance_miles = 10;
    let duration_seconds = 0;

    try {
      const routeResponse = await axios.post(`${ROUTING_SERVICE_URL}/route/calculate`, {
        origin,
        destination,
      });
      distance_miles   = routeResponse.data?.distance_miles  || 10;
      duration_seconds = routeResponse.data?.duration_seconds || 0;
    } catch {
      console.warn('Routing service unavailable, using default distance of 10 miles');
    }

    const duration_hours  = duration_seconds / 3600;
    const total_trip_cost = distance_miles * IRS_MILEAGE_RATE + duration_hours * DRIVER_HOURLY;
    const price_per_rider = total_trip_cost / num_riders;

    const breakdown = {
      distance_miles:   parseFloat(distance_miles.toFixed(2)),
      duration_hours:   parseFloat(duration_hours.toFixed(4)),
      irs_mileage_rate: IRS_MILEAGE_RATE,
      driver_hourly:    DRIVER_HOURLY,
      total_trip_cost:  parseFloat(total_trip_cost.toFixed(2)),
      price_per_rider:  parseFloat(price_per_rider.toFixed(2)),
    };

    res.json({
      status: 'success',
      message: 'Cost calculated successfully',
      data: {
        max_price: parseFloat(price_per_rider.toFixed(2)),
        breakdown,
      },
    });
  } catch (error) {
    console.error('Cost calculation error:', error);
    res.status(500).json({ status: 'error', message: 'Failed to calculate cost' });
  }
});

// ── GET /cost/settle/:trip_id ─────────────────────────────────────────────────
// IRS mileage-rate settlement for a completed trip.
// Called by trip-service when a trip transitions to 'completed'.
app.get('/cost/settle/:trip_id', async (req, res) => {
  const { trip_id } = req.params;

  try {
    // STEP 1 — Fetch trip details
    let trip: any;
    try {
      const tripResp = await axios.get(`${TRIP_SERVICE_URL}/trips/${trip_id}`);
      trip = tripResp.data?.data ?? tripResp.data;
    } catch (err: any) {
      if (err?.response?.status === 404) {
        res.status(404).json({ status: 'error', message: `Trip ${trip_id} not found` });
        return;
      }
      throw err;
    }

    if (!trip || !trip.trip_id) {
      res.status(404).json({ status: 'error', message: `Trip ${trip_id} not found` });
      return;
    }

    const originCoord = (trip.origin_point?.lat != null && trip.origin_point?.lng != null)
      ? `${trip.origin_point.lat},${trip.origin_point.lng}` : trip.origin;
    const destCoord = (trip.destination_point?.lat != null && trip.destination_point?.lng != null)
      ? `${trip.destination_point.lat},${trip.destination_point.lng}` : trip.destination;
    console.log(`[settle] routing coords: origin=${originCoord} dest=${destCoord}`);

    // STEP 2 — Fetch bookings via internal no-auth route
    let bookings: any[] = [];
    try {
      const bookingsResp = await axios.get(`${BOOKING_SERVICE_URL}/bookings/trip/${trip_id}/settle`);
      console.log('[settle-debug] raw bookings response:', JSON.stringify(bookingsResp.data).substring(0, 500));
      const raw = bookingsResp.data?.data ?? bookingsResp.data;
      bookings = Array.isArray(raw) ? raw
               : Array.isArray(raw?.bookings) ? raw.bookings
               : [];
    } catch (err: any) {
      console.warn(`[settle] Could not fetch bookings for trip ${trip_id}: ${err?.message}`);
    }

    // Accept only bookings that are approved (not cancelled/rejected)
    const confirmedBookings = bookings.filter(
      (b: any) => !['cancelled', 'canceled', 'rejected'].includes(b.booking_state)
    );

    const riderCount = confirmedBookings.reduce(
      (sum: number, b: any) => sum + (parseInt(b.seats_booked, 10) || 1), 0
    );
    console.log(`[settle] trip ${trip_id}: fetched ${bookings.length} bookings, ${confirmedBookings.length} accepted, riderCount=${riderCount}`);

    // STEP 3 — Direct trip distance + duration
    let direct_distance_miles = 10;
    let direct_duration_seconds = 0;
    try {
      const routeResp = await axios.post(`${ROUTING_SERVICE_URL}/route/calculate`, {
        origin: originCoord,
        destination: destCoord,
      });
      direct_distance_miles    = routeResp.data?.distance_miles    ?? 10;
      direct_duration_seconds  = routeResp.data?.duration_seconds  ?? 0;
      console.log(`[settle] direct distance: ${direct_distance_miles.toFixed(2)} miles, duration: ${direct_duration_seconds}s`);
    } catch {
      console.warn('[settle] Routing unavailable, using 10 mi / 0s defaults');
    }

    // STEP 4 — Per-rider settlement (IRS mileage rate formula)
    const direct_duration_hours = direct_duration_seconds / 3600;
    const trip_cost         = direct_distance_miles * IRS_MILEAGE_RATE + direct_duration_hours * DRIVER_HOURLY;
    // Guard against riderCount=0 (no confirmed bookings) to avoid NaN/Infinity
    const shared_per_rider  = riderCount > 0 ? trip_cost / riderCount : trip_cost;

    const riderSettlements: any[] = [];

    for (const booking of confirmedBookings) {
      const riderId     = booking.rider_id;
      const riderName   = booking.rider_name ?? booking.rider?.name ?? 'Rider';
      const seatsBooked = parseInt(booking.seats_booked, 10) || 1;

      let detour_miles = 0;
      let detour_cost  = 0;
      let breakdown    = `Base share: $${shared_per_rider.toFixed(2)}`;

      // Parse pickup_location — handle object, JSON string, or plain "lat,lng" string
      let loc: any = null;
      if (booking.pickup_location) {
        try {
          loc = typeof booking.pickup_location === 'string'
            ? JSON.parse(booking.pickup_location)
            : booking.pickup_location;
        } catch {
          const parts = String(booking.pickup_location).split(',');
          if (parts.length === 2) {
            loc = { lat: parseFloat(parts[0]), lng: parseFloat(parts[1]) };
          }
        }
      }

      // Detour cost if rider has a custom pickup off the direct route
      if (loc && (loc.address || (loc.lat != null && loc.lng != null))) {
        const pickupAddr = loc.address ?? `${loc.lat},${loc.lng}`;
        try {
          const [leg1Resp, leg2Resp] = await Promise.all([
            axios.post(`${ROUTING_SERVICE_URL}/route/calculate`, { origin: originCoord, destination: pickupAddr }),
            axios.post(`${ROUTING_SERVICE_URL}/route/calculate`, { origin: pickupAddr, destination: destCoord }),
          ]);
          const toPickupDist   = leg1Resp.data?.distance_miles ?? 0;
          const fromPickupDist = leg2Resp.data?.distance_miles ?? 0;
          detour_miles = Math.max(0, (toPickupDist + fromPickupDist) - direct_distance_miles);
          console.log(`[settle-debug] rider ${riderId}: toPickup=${toPickupDist} fromPickup=${fromPickupDist} detour=${detour_miles}`);
          if (detour_miles > 0.1) {
            detour_cost = detour_miles * IRS_MILEAGE_RATE * DETOUR_SURCHARGE;
            breakdown += ` + ${detour_miles.toFixed(2)} mi detour surcharge`;
          }
        } catch {
          console.warn(`[settle] Routing failed for rider ${riderId} detour calc`);
        }
      }

      // Cap at hold amount (max_price from quote, already on the booking row as `fare`)
      const holdAmount = booking.fare != null ? parseFloat(booking.fare) : (shared_per_rider + detour_cost);

      const raw_amount   = (shared_per_rider + detour_cost) * seatsBooked;
      const amount_paid  = parseFloat(Math.min(raw_amount, holdAmount * seatsBooked).toFixed(2));

      riderSettlements.push({
        rider_id:     riderId,
        rider_name:   riderName,
        amount_paid,
        status:       booking.status,
        detour_miles: parseFloat(detour_miles.toFixed(2)),
        breakdown,
      });
    }

    // STEP 5 — Build response
    const totalDriverEarnings = parseFloat(
      riderSettlements.reduce((sum, r) => sum + r.amount_paid, 0).toFixed(2)
    );

    res.json({
      status: 'success',
      message: 'Settlement calculated successfully (IRS mileage rate)',
      data: {
        trip_id,
        irs_mileage_rate: IRS_MILEAGE_RATE,
        driver_hourly:    DRIVER_HOURLY,
        total_cost:      totalDriverEarnings,
        driver_earnings: totalDriverEarnings,
        rider_count:     riderCount > 0 ? riderCount : 1,
        cost_per_rider:  parseFloat(shared_per_rider.toFixed(2)),
        breakdown: {
          direct_distance_miles:  parseFloat(direct_distance_miles.toFixed(2)),
          direct_duration_hours:  parseFloat(direct_duration_hours.toFixed(4)),
          trip_cost:              parseFloat(trip_cost.toFixed(2)),
          detour_surcharge:       DETOUR_SURCHARGE,
        },
        riders: riderSettlements,
      },
    });
  } catch (error: any) {
    console.error(`[settle] Error for trip ${trip_id}:`, error?.message ?? error);
    res.status(500).json({
      status: 'error',
      message: `Failed to calculate trip settlement: ${error?.message ?? 'Unknown error'}`,
    });
  }
});

export default app;
