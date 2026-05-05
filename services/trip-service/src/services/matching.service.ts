/**
 * matching.service.ts
 * -------------------
 * Three-stage matching pipeline:
 *   1. RShareForm embedding service (Tang et al. 2020) → ranked candidate list
 *   2. PostGIS feasibility filter  (He et al. 2014)   → 800 m origin proximity,
 *                                                         ±10 min departure window
 *   3. Scost ranking               (He et al. eq 9)   → best feasible driver selected
 *
 * Writes a pending_match row (15-second expiry) and fires a driver-request
 * notification so the driver's iOS app shows the incoming-request card.
 */

import { Pool } from 'pg';
import axios from 'axios';
import { config } from '../config';

const pool = new Pool({ connectionString: config.databaseUrl });

// ── Scost weights (He et al. eq 9) ─────────────────────────────────────────
const W1 = 0.5;  // average detour distance
const W2 = 0.2;  // walking distance
const W3 = 0.1;  // extra distance penalty
const W4 = 0.1;  // waiting time
const W5 = 0.1;  // route compatibility (frequent edge score)

const D_MAX = 5000;   // max acceptable walking distance (m)
const T_MAX = 1800;   // max acceptable wait (s, 30 min)
const ZETA  = 800;    // route-compatibility threshold (m)

// Equilibrium constants (He et al. eq 8)
const RHO = 0.1;

// Carpool detour threshold: reject en-route candidates that would add
// more than 30% extra distance per existing passenger's journey.
const MAX_PASSENGER_DETOUR_RATIO = 0.30;

// ── Haversine helper ─────────────────────────────────────────────────────────
function haversineMeters(
  lat1: number, lng1: number,
  lat2: number, lng2: number
): number {
  const R = 6_371_000;
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(Δφ / 2) ** 2 +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── Types ───────────────────────────────────────────────────────────────────
interface TripRequestRow {
  request_id: string;
  rider_id: string;
  origin_lat: number;
  origin_lng: number;
  destination_lat: number;
  destination_lng: number;
  departure_time: Date;
  max_scost: number | null;  // rider-preference ceiling (He et al. §4.2); null = no gate
}

export interface CandidateTrip {
  trip_id: string;
  driver_id: string;
  origin_lat: number;
  origin_lng: number;
  destination_lat: number;
  destination_lng: number;
  departure_time: Date;
  distance_to_rider_m: number;
  seats_available: number;
  route_score: number;  // from frequent_routes (Se, defaults to 0)
}

// ── Stage 1: fetch PostGIS-filtered candidates ───────────────────────────────
//
// Proximity radius: 5 000 m (5 km) — expanded from the paper's 800 m because
// Bay Area SJSU commutes involve pickups from distant transit hubs (Milpitas BART,
// Berryessa, etc.) where a 1–3 km walk-to-meetup is acceptable.
//
// Departure window: ±30 min — expanded from He et al. ±10 min so that trips
// planned ~30 min ahead can match riders who request "leave now + 15 min", which
// is the common case for student commutes.
async function fetchCandidates(req: TripRequestRow): Promise<CandidateTrip[]> {
  const riderPoint = `ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography`;

  // Stage 1a: pending trips within 5 km and ±30 min departure window
  const pendingResult = await pool.query<CandidateTrip>(
    `SELECT
       t.trip_id,
       t.driver_id,
       ST_Y(t.origin_point::geometry)       AS origin_lat,
       ST_X(t.origin_point::geometry)       AS origin_lng,
       ST_Y(t.destination_point::geometry)  AS destination_lat,
       ST_X(t.destination_point::geometry)  AS destination_lng,
       t.departure_time,
       t.seats_available,
       ST_Distance(
         t.origin_point::geography,
         ${riderPoint}
       ) AS distance_to_rider_m,
       0 AS route_score
     FROM trips t
     JOIN users u ON t.driver_id = u.user_id
                  AND u.available_for_rides = true
                  AND u.role = 'Driver'
     WHERE t.status = 'pending'
       AND t.seats_available >= 1
       AND ST_DWithin(
             t.origin_point::geography,
             ${riderPoint},
             5000
           )
       AND t.departure_time BETWEEN ($3::timestamptz - INTERVAL '30 minutes')
                                AND ($3::timestamptz + INTERVAL '30 minutes')
     ORDER BY distance_to_rider_m ASC
     LIMIT 20`,
    [req.origin_lng, req.origin_lat, req.departure_time]
  );

  // Stage 1b: carpool candidates — en-route / in-progress drivers with available
  // seats whose route (origin→destination line) passes within 1.5 km of the new
  // rider's pickup, and whose destination is in roughly the same direction.
  const carpoolResult = await pool.query<CandidateTrip>(
    `SELECT
       t.trip_id,
       t.driver_id,
       ST_Y(t.origin_point::geometry)       AS origin_lat,
       ST_X(t.origin_point::geometry)       AS origin_lng,
       ST_Y(t.destination_point::geometry)  AS destination_lat,
       ST_X(t.destination_point::geometry)  AS destination_lng,
       t.departure_time,
       t.seats_available,
       ST_Distance(
         t.origin_point::geography,
         ${riderPoint}
       ) AS distance_to_rider_m,
       0 AS route_score
     FROM trips t
     JOIN users u ON t.driver_id = u.user_id
                  AND u.role = 'Driver'
     WHERE t.status IN ('en_route', 'in_progress')
       AND t.seats_available >= 1
       -- Rider's pickup must lie within 1.5 km of the driver's origin→destination route line
       AND ST_DWithin(
             ST_MakeLine(
               t.origin_point::geometry,
               t.destination_point::geometry
             )::geography,
             ${riderPoint},
             1500
           )
       -- Driver's destination within 8 km of rider's destination (going the same way)
       AND ST_DWithin(
             t.destination_point::geography,
             ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
             8000
           )
     ORDER BY distance_to_rider_m ASC
     LIMIT 10`,
    [req.origin_lng, req.origin_lat, req.destination_lng, req.destination_lat]
  );

  // Merge, deduplicate by trip_id
  const seen = new Set<string>();
  const combined: CandidateTrip[] = [];
  for (const row of [...pendingResult.rows, ...carpoolResult.rows]) {
    if (!seen.has(row.trip_id)) {
      seen.add(row.trip_id);
      combined.push(row);
    }
  }

  console.log(
    `[matching] fetchCandidates: ${pendingResult.rows.length} pending + ` +
    `${carpoolResult.rows.length} carpool = ${combined.length} unique candidates ` +
    `for request ${req.request_id}`
  );
  combined.forEach(r =>
    console.log(`  → trip ${r.trip_id} | driver ${r.driver_id} | dist=${Math.round(r.distance_to_rider_m)}m | seats=${r.seats_available}`)
  );
  return combined;
}

// ── Stage 2: call embedding service for similarity ranking ───────────────────
async function rankWithEmbedding(
  req: TripRequestRow,
  candidates: CandidateTrip[]
): Promise<CandidateTrip[]> {
  if (candidates.length === 0) return [];
  try {
    const hour = new Date(req.departure_time).getHours();
    const payload = {
      rider_origin_lat:  req.origin_lat,
      rider_origin_lng:  req.origin_lng,
      rider_dest_lat:    req.destination_lat,
      rider_dest_lng:    req.destination_lng,
      rider_hour:        hour,
      candidates: candidates.map(c => ({
        trip_id:         c.trip_id,
        driver_id:       c.driver_id,
        origin_lat:      c.origin_lat,
        origin_lng:      c.origin_lng,
        destination_lat: c.destination_lat,
        destination_lng: c.destination_lng,
        departure_time:  c.departure_time.toISOString(),
      })),
    };
    const { data } = await axios.post(
      `${config.embeddingServiceUrl}/match`,
      payload,
      { timeout: 5000 }
    );

    if (!data.model_used) {
      console.log('[matching] Embedding service: model not trained yet, using PostGIS distance order.');
      return candidates;
    }

    console.log(`[matching] Embedding service returned ${data.ranked?.length ?? 0} ranked candidate(s).`);
    const similarityMap = new Map<string, number>(
      data.ranked.map((r: any) => [r.trip_id, r.similarity])
    );
    data.ranked.forEach((r: any) =>
      console.log(`  → trip ${r.trip_id} similarity=${r.similarity?.toFixed(4)}`)
    );

    return [...candidates].sort(
      (a, b) =>
        (similarityMap.get(b.trip_id) ?? 0) - (similarityMap.get(a.trip_id) ?? 0)
    );
  } catch (err) {
    // Embedding service down → fall back to PostGIS distance order
    console.warn('[matching] Embedding service unavailable, falling back to PostGIS ranking:', (err as Error).message);
    return candidates;
  }
}

// ── Stage 3: Scost computation (He et al. eq 9) ─────────────────────────────
//
// Parameters
//   hasSocialHistory – true if rider & driver have ≥1 past shared booking.
//                      He et al. §4.2.5: social distance is a *reward* for
//                      familiarity, not a punishment for novelty. Strangers
//                      receive a neutral social score of 0.
//
// Advance-time component (term4)
//   He et al. treats immediate requests (depTime ≈ now) as a valid booking
//   mode with no advance-time penalty. We zero term4 when the rider's
//   requested departure is within 5 minutes of the current time.
interface ScostBreakdown {
  travel: number; walk: number; detour: number; advance: number; social: number; total: number;
}

function computeScost(
  req: TripRequestRow,
  trip: CandidateTrip,
  existingPassengers: number,
  hasSocialHistory: boolean
): ScostBreakdown {
  const dp = haversineMeters(req.origin_lat, req.origin_lng, req.destination_lat, req.destination_lng);
  const dw = haversineMeters(req.origin_lat, req.origin_lng, trip.origin_lat, trip.origin_lng);

  const detourPerPassenger = dw;
  const m = existingPassengers + 1;
  const extraDistance = Math.max(0, 2 * (m * detourPerPassenger - dp));

  // Carpool guard: if adding this rider would detour existing passengers by > 30%
  // of their original trip distance, reject by returning infinite Scost.
  // This maps He et al. eq 7b into the Scost computation for en-route trips.
  if (existingPassengers > 0) {
    const newPassengerDetourRatio = dw / Math.max(dp, 1);
    if (newPassengerDetourRatio > MAX_PASSENGER_DETOUR_RATIO) {
      return { travel: Infinity, walk: Infinity, detour: Infinity, advance: Infinity, social: Infinity, total: Infinity };
    }
  }

  // Advance-time: zero for immediate requests (|depTime - now| < 5 min).
  const nowMs = Date.now();
  const reqDepMs = new Date(req.departure_time).getTime();
  const isImmediateRequest = Math.abs(reqDepMs - nowMs) < 5 * 60 * 1000;
  const waitSeconds = isImmediateRequest
    ? 0
    : Math.max(0, (new Date(trip.departure_time).getTime() - reqDepMs) / 1000);

  // Social distance: 0 (neutral) for strangers; positive for known pairs.
  // Currently we model the social term from past shared-ride frequency.
  // For any rider/driver pair with no history the component is 0 (He et al. §4.2.5).
  const socialScore = hasSocialHistory ? W5 * Math.min(dw, ZETA) / ZETA : 0;

  const travel  = W1 * (detourPerPassenger / Math.max(dp, 1));
  const walk    = W2 * (dw / Math.max(D_MAX, 1));
  const detour  = W3 * (extraDistance / Math.max(dp, 1));
  const advance = W4 * (waitSeconds / Math.max(T_MAX, 1));
  const social  = socialScore;

  return { travel, walk, detour, advance, social, total: travel + walk + detour + advance + social };
}

// ── Equilibrium test (He et al. eq 8) ───────────────────────────────────────
function passesEquilibrium(scostNew: number, scostPrev: number | null): boolean {
  if (scostPrev === null) return true;
  if (scostNew >= scostPrev) return false;
  return (scostPrev - scostNew) / scostPrev < RHO;
}

// ── Write pending_match row ──────────────────────────────────────────────────
async function insertPendingMatch(
  requestId: string,
  tripId: string,
  driverId: string,
  score: number,
  attempt: number
): Promise<string> {
  const result = await pool.query(
    `INSERT INTO pending_matches (request_id, trip_id, driver_id, score, attempt)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING match_id`,
    [requestId, tripId, driverId, score, attempt]
  );
  return result.rows[0].match_id as string;
}

// ── Notify driver via notification service ───────────────────────────────────
async function notifyDriver(
  driverId: string,
  matchId: string,
  requestId: string,
  tripId: string,
  riderInfo: { name: string; rating: number },
  tripInfo: { origin: string; destination: string; departure_time: string }
): Promise<void> {
  try {
    await axios.post(
      `${config.notificationServiceUrl}/notifications/driver-request`,
      {
        driver_id:    driverId,
        match_id:     matchId,
        request_id:   requestId,
        trip_id:      tripId,
        rider_name:   riderInfo.name,
        rider_rating: riderInfo.rating,
        origin:       tripInfo.origin,
        destination:  tripInfo.destination,
        departure_time: tripInfo.departure_time,
      },
      { timeout: 3000 }
    );
  } catch (err) {
    console.warn('[matching] Driver notification failed (non-fatal):', err);
  }
}

// ── Main entry point ─────────────────────────────────────────────────────────

/**
 * Run the full three-stage matching pipeline for a trip request.
 * Returns the top-5 candidate driver trips ranked by Scost. No pending_match
 * is created here — the rider selects from this list and the match is
 * committed via selectDriverForRider().
 */
export async function matchRider(
  requestId: string,
  attempt: number = 1
): Promise<CandidateTrip[]> {
  console.log(`[matching] matchRider: attempt=${attempt} requestId=${requestId}`);

  const reqResult = await pool.query<TripRequestRow>(
    `SELECT request_id, rider_id,
            origin_lat, origin_lng, destination_lat, destination_lng,
            departure_time, max_scost
     FROM trip_requests WHERE request_id = $1`,
    [requestId]
  );
  if (reqResult.rows.length === 0) {
    throw new Error(`Trip request ${requestId} not found`);
  }
  const req = reqResult.rows[0];
  console.log(`[matching] Request origin=(${req.origin_lat},${req.origin_lng}) dest=(${req.destination_lat},${req.destination_lng}) depTime=${req.departure_time}`);

  // Stage 1: PostGIS proximity filter
  let candidates = await fetchCandidates(req);
  if (candidates.length === 0) {
    console.warn(`[matching] No candidates found. Possible reasons: no drivers with available_for_rides=true, no pending trips within 5km / ±30min.`);
    return [];
  }

  // Stage 2: RShareForm embedding ranking
  candidates = await rankWithEmbedding(req, candidates);

  // Stage 3: Collect all drivers that pass the Scost gate (He et al. eq 9),
  // sort by Scost ascending, and return the top 5 for rider selection.
  const riderMaxScost: number | null = req.max_scost ?? null;
  const ranked: Array<{ trip: CandidateTrip; scost: number }> = [];

  for (const trip of candidates) {
    const existingPassengersResult = await pool.query<{ count: string }>(
      `SELECT COUNT(*) FROM bookings
       WHERE trip_id = $1 AND status NOT IN ('cancelled')`,
      [trip.trip_id]
    );
    const existingPassengers = parseInt(existingPassengersResult.rows[0].count, 10);

    const socialResult = await pool.query<{ count: string }>(
      `SELECT COUNT(*) FROM bookings b
       JOIN trips t ON b.trip_id = t.trip_id
       WHERE b.rider_id = $1 AND t.driver_id = $2
         AND b.status NOT IN ('cancelled')`,
      [req.rider_id, trip.driver_id]
    );
    const hasSocialHistory = parseInt(socialResult.rows[0].count, 10) > 0;

    const bd = computeScost(req, trip, existingPassengers, hasSocialHistory);

    const exceedsRiderCeiling = riderMaxScost !== null && bd.total > riderMaxScost;
    const decision = exceedsRiderCeiling
      ? `SKIP (Scost=${bd.total.toFixed(3)} > rider maxScost=${riderMaxScost})`
      : !isFinite(bd.total)
        ? 'SKIP (detour ratio exceeded)'
        : `ACCEPT Scost=${bd.total.toFixed(3)}`;

    console.log(
      `[matching] Candidate ${trip.trip_id} (driver ${trip.driver_id}): ` +
      `travel=${bd.travel.toFixed(3)} walk=${bd.walk.toFixed(3)} ` +
      `detour=${bd.detour.toFixed(3)} advance=${bd.advance.toFixed(3)} ` +
      `social=${bd.social.toFixed(3)} total=${isFinite(bd.total) ? bd.total.toFixed(3) : 'Inf'} | ${decision}`
    );

    if (!exceedsRiderCeiling && isFinite(bd.total)) {
      ranked.push({ trip, scost: bd.total });
    }
  }

  ranked.sort((a, b) => a.scost - b.scost);
  const top5 = ranked.slice(0, 5).map(r => r.trip);

  console.log(`[matching] matchRider: ${top5.length} candidate(s) returned for request ${requestId}`);
  return top5;
}

/**
 * Accept a pending match: update match + request status, decrement seats.
 */
export async function acceptMatch(matchId: string, driverId: string): Promise<void> {
  const result = await pool.query(
    `UPDATE pending_matches
     SET status = 'accepted'
     WHERE match_id = $1 AND driver_id = $2 AND status = 'pending' AND expires_at > NOW()
     RETURNING request_id, trip_id`,
    [matchId, driverId]
  );
  if (result.rows.length === 0) {
    throw new Error('Match not found, already expired, or not owned by this driver.');
  }
  const { request_id, trip_id } = result.rows[0];

  // Get rider ID from request
  const reqRow = await pool.query<{ rider_id: string }>(
    `UPDATE trip_requests SET status = 'matched', matched_trip_id = $2, updated_at = NOW()
     WHERE request_id = $1 RETURNING rider_id`,
    [request_id, trip_id]
  );

  console.log(`[matching] Match ${matchId} accepted. Rider ${reqRow.rows[0]?.rider_id} → trip ${trip_id}`);
}

/**
 * Decline a pending match: expire this match and retry with the next candidate
 * (up to MAX_ATTEMPTS).
 */
const MAX_ATTEMPTS = 5;

export async function declineMatch(matchId: string, driverId: string): Promise<void> {
  const result = await pool.query(
    `UPDATE pending_matches
     SET status = 'declined'
     WHERE match_id = $1 AND driver_id = $2 AND status = 'pending'
     RETURNING request_id, attempt`,
    [matchId, driverId]
  );
  if (result.rows.length === 0) return;

  const { request_id, attempt } = result.rows[0];
  if (attempt < MAX_ATTEMPTS) {
    // Re-run pipeline and forward to the next best candidate asynchronously.
    setImmediate(async () => {
      try {
        const candidates = await matchRider(request_id, attempt + 1);
        if (candidates.length > 0) {
          // Skip the driver who just declined; fall back to them only if no other option.
          const next = candidates.find(c => c.driver_id !== driverId) ?? candidates[0];
          await selectDriverForRider(request_id, next.trip_id, next.driver_id, attempt + 1);
        }
      } catch (err) {
        console.error('[matching] declineMatch retry error:', err);
      }
    });
  } else {
    // Exhaust retries: mark request expired
    await pool.query(
      `UPDATE trip_requests SET status = 'expired', updated_at = NOW() WHERE request_id = $1`,
      [request_id]
    );
    console.warn(`[matching] Request ${request_id} exhausted ${MAX_ATTEMPTS} match attempts.`);
  }
}

// ── Driver-initiated pooling ──────────────────────────────────────────────────

/**
 * Inverted three-stage pipeline triggered when a driver posts a new trip.
 * Scans the pool of pending rider requests, finds the best match by Scost,
 * creates a pending_match, and pings the driver so they see the pooled rider.
 */
export async function matchDriver(tripId: string): Promise<void> {
  console.log(`[matching] matchDriver: tripId=${tripId}`);

  // Load the newly posted driver trip
  const tripResult = await pool.query<{
    trip_id: string; driver_id: string;
    origin_lat: number; origin_lng: number;
    destination_lat: number; destination_lng: number;
    departure_time: Date; seats_available: number;
    origin: string; destination: string;
  }>(
    `SELECT trip_id, driver_id,
            ST_Y(origin_point::geometry)      AS origin_lat,
            ST_X(origin_point::geometry)      AS origin_lng,
            ST_Y(destination_point::geometry) AS destination_lat,
            ST_X(destination_point::geometry) AS destination_lng,
            departure_time, seats_available, origin, destination
     FROM trips WHERE trip_id = $1`,
    [tripId]
  );
  if (tripResult.rows.length === 0) {
    console.warn(`[matching] matchDriver: trip ${tripId} not found`);
    return;
  }
  const trip = tripResult.rows[0];

  // Stage 1 (PostGIS Inverted): pending rider requests whose origin is within
  // 5 000 m of the trip origin OR within 1 500 m of the origin→destination route
  // line, whose destination is within 8 000 m, and whose departure time is ±30 min.
  const candidateResult = await pool.query<TripRequestRow>(
    `SELECT request_id, rider_id,
            origin_lat, origin_lng, destination_lat, destination_lng,
            departure_time, max_scost
     FROM trip_requests
     WHERE status = 'pending'
       AND (
         ST_DWithin(
           ST_SetSRID(ST_MakePoint(origin_lng, origin_lat), 4326)::geography,
           ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
           5000
         )
         OR ST_DWithin(
           ST_MakeLine(
             ST_SetSRID(ST_MakePoint($1, $2), 4326),
             ST_SetSRID(ST_MakePoint($3, $4), 4326)
           )::geography,
           ST_SetSRID(ST_MakePoint(origin_lng, origin_lat), 4326)::geography,
           1500
         )
       )
       AND ST_DWithin(
         ST_SetSRID(ST_MakePoint(destination_lng, destination_lat), 4326)::geography,
         ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography,
         8000
       )
       AND departure_time BETWEEN ($5::timestamptz - INTERVAL '30 minutes')
                              AND ($5::timestamptz + INTERVAL '30 minutes')
     ORDER BY ST_Distance(
       ST_SetSRID(ST_MakePoint(origin_lng, origin_lat), 4326)::geography,
       ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
     ) ASC
     LIMIT 20`,
    [trip.origin_lng, trip.origin_lat, trip.destination_lng, trip.destination_lat, trip.departure_time]
  );

  const candidateRiders = candidateResult.rows;
  if (candidateRiders.length === 0) {
    console.log(`[matching] matchDriver: no pending riders near trip ${tripId}`);
    return;
  }
  console.log(`[matching] matchDriver: ${candidateRiders.length} candidate rider(s) for trip ${tripId}`);

  // Stage 2: RShareForm embedding ranking.
  // Use the driver's route as the query and map each rider request to a
  // CandidateTrip shape so rankWithEmbedding can score trajectory similarity.
  const syntheticReq: TripRequestRow = {
    request_id:      trip.trip_id,
    rider_id:        trip.driver_id,
    origin_lat:      trip.origin_lat,
    origin_lng:      trip.origin_lng,
    destination_lat: trip.destination_lat,
    destination_lng: trip.destination_lng,
    departure_time:  trip.departure_time,
    max_scost:       null,
  };

  const ridersAsCandidates: CandidateTrip[] = candidateRiders.map(r => ({
    trip_id:             r.request_id,
    driver_id:           r.rider_id,
    origin_lat:          r.origin_lat,
    origin_lng:          r.origin_lng,
    destination_lat:     r.destination_lat,
    destination_lng:     r.destination_lng,
    departure_time:      r.departure_time,
    distance_to_rider_m: 0,
    seats_available:     1,
    route_score:         0,
  }));

  const rankedAsCandidates = await rankWithEmbedding(syntheticReq, ridersAsCandidates);

  // Restore TripRequestRow order from the embedding-ranked list
  const riderMap = new Map(candidateRiders.map(r => [r.request_id, r]));
  const rankedRiders = rankedAsCandidates
    .map(c => riderMap.get(c.trip_id))
    .filter((r): r is TripRequestRow => r !== undefined);

  // Stage 3: Scost — pick the rider with the lowest valid Scost (He et al. eq 9)
  const driverAsCandidate: CandidateTrip = {
    trip_id:             trip.trip_id,
    driver_id:           trip.driver_id,
    origin_lat:          trip.origin_lat,
    origin_lng:          trip.origin_lng,
    destination_lat:     trip.destination_lat,
    destination_lng:     trip.destination_lng,
    departure_time:      trip.departure_time,
    distance_to_rider_m: 0,
    seats_available:     trip.seats_available,
    route_score:         0,
  };

  const existingPassengersResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) FROM bookings WHERE trip_id = $1 AND status NOT IN ('cancelled')`,
    [tripId]
  );
  const existingPassengers = parseInt(existingPassengersResult.rows[0].count, 10);

  let bestRider: TripRequestRow | null = null;
  let bestScost = Infinity;

  for (const riderReq of rankedRiders) {
    const socialResult = await pool.query<{ count: string }>(
      `SELECT COUNT(*) FROM bookings b
       JOIN trips t ON b.trip_id = t.trip_id
       WHERE b.rider_id = $1 AND t.driver_id = $2
         AND b.status NOT IN ('cancelled')`,
      [riderReq.rider_id, trip.driver_id]
    );
    const hasSocialHistory = parseInt(socialResult.rows[0].count, 10) > 0;

    const bd = computeScost(riderReq, driverAsCandidate, existingPassengers, hasSocialHistory);
    const exceedsRiderCeiling = riderReq.max_scost !== null && bd.total > riderReq.max_scost;

    console.log(
      `[matching] matchDriver rider ${riderReq.request_id}: ` +
      `Scost=${isFinite(bd.total) ? bd.total.toFixed(3) : 'Inf'} exceedsCeiling=${exceedsRiderCeiling}`
    );

    if (!exceedsRiderCeiling && isFinite(bd.total) && bd.total < bestScost) {
      bestRider = riderReq;
      bestScost = bd.total;
    }
  }

  if (!bestRider) {
    console.warn(`[matching] matchDriver: no qualifying rider for trip ${tripId}`);
    return;
  }

  const riderInfoResult = await pool.query<{ name: string; rating: number }>(
    `SELECT name, COALESCE(rating, 5.0) AS rating FROM users WHERE user_id = $1`,
    [bestRider.rider_id]
  );
  const riderInfo = riderInfoResult.rows[0] ?? { name: 'Rider', rating: 5.0 };

  const matchId = await insertPendingMatch(bestRider.request_id, tripId, trip.driver_id, bestScost, 1);
  await notifyDriver(trip.driver_id, matchId, bestRider.request_id, tripId, riderInfo, {
    origin:         trip.origin,
    destination:    trip.destination,
    departure_time: new Date(trip.departure_time).toISOString(),
  });

  console.log(`[matching] matchDriver: match ${matchId} → rider ${bestRider.rider_id} (Scost=${bestScost.toFixed(3)})`);
}

// ── Rider-initiated driver selection ─────────────────────────────────────────

/**
 * Called when a rider taps a specific driver from the ranked list returned by
 * matchRider(). Computes the final Scost, creates the pending_match row, and
 * sends the driver a push notification to accept or deny within 15 seconds.
 *
 * @returns match_id of the created pending_match
 */
export async function selectDriverForRider(
  requestId: string,
  tripId: string,
  driverId: string,
  attempt: number = 1
): Promise<string> {
  console.log(`[matching] selectDriverForRider: requestId=${requestId} tripId=${tripId} driverId=${driverId}`);

  // Validate request is still pending
  const reqResult = await pool.query<TripRequestRow>(
    `SELECT request_id, rider_id,
            origin_lat, origin_lng, destination_lat, destination_lng,
            departure_time, max_scost
     FROM trip_requests WHERE request_id = $1 AND status = 'pending'`,
    [requestId]
  );
  if (reqResult.rows.length === 0) {
    throw new Error(`Trip request ${requestId} not found or not pending`);
  }
  const req = reqResult.rows[0];

  // Load the selected driver's trip, including display labels for the notification
  const tripResult = await pool.query<{
    trip_id: string; driver_id: string;
    origin_lat: number; origin_lng: number;
    destination_lat: number; destination_lng: number;
    departure_time: Date; seats_available: number;
    origin: string; destination: string;
  }>(
    `SELECT trip_id, driver_id,
            ST_Y(origin_point::geometry)      AS origin_lat,
            ST_X(origin_point::geometry)      AS origin_lng,
            ST_Y(destination_point::geometry) AS destination_lat,
            ST_X(destination_point::geometry) AS destination_lng,
            departure_time, seats_available, origin, destination
     FROM trips WHERE trip_id = $1 AND driver_id = $2`,
    [tripId, driverId]
  );
  if (tripResult.rows.length === 0) {
    throw new Error(`Trip ${tripId} not found or not owned by driver ${driverId}`);
  }
  const tripRow = tripResult.rows[0];

  const trip: CandidateTrip = {
    trip_id:             tripRow.trip_id,
    driver_id:           tripRow.driver_id,
    origin_lat:          tripRow.origin_lat,
    origin_lng:          tripRow.origin_lng,
    destination_lat:     tripRow.destination_lat,
    destination_lng:     tripRow.destination_lng,
    departure_time:      tripRow.departure_time,
    seats_available:     tripRow.seats_available,
    route_score:         0,
    distance_to_rider_m: 0,
  };

  const existingResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) FROM bookings WHERE trip_id = $1 AND status NOT IN ('cancelled')`,
    [tripId]
  );
  const existingPassengers = parseInt(existingResult.rows[0].count, 10);

  const socialResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) FROM bookings b
     JOIN trips t ON b.trip_id = t.trip_id
     WHERE b.rider_id = $1 AND t.driver_id = $2
       AND b.status NOT IN ('cancelled')`,
    [req.rider_id, driverId]
  );
  const hasSocialHistory = parseInt(socialResult.rows[0].count, 10) > 0;

  const bd = computeScost(req, trip, existingPassengers, hasSocialHistory);

  const riderInfoResult = await pool.query<{ name: string; rating: number }>(
    `SELECT name, COALESCE(rating, 5.0) AS rating FROM users WHERE user_id = $1`,
    [req.rider_id]
  );
  const riderInfo = riderInfoResult.rows[0] ?? { name: 'Rider', rating: 5.0 };

  const matchId = await insertPendingMatch(requestId, tripId, driverId, bd.total, attempt);
  await notifyDriver(driverId, matchId, requestId, tripId, riderInfo, {
    origin:         tripRow.origin,
    destination:    tripRow.destination,
    departure_time: new Date(tripRow.departure_time).toISOString(),
  });

  console.log(`[matching] selectDriverForRider: match ${matchId} → driver ${driverId} (Scost=${bd.total.toFixed(3)})`);
  return matchId;
}
