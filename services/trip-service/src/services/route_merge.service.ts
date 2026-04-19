/**
 * route_merge.service.ts
 * ----------------------
 * He et al. 2014, Algorithm 3 – incremental pairwise route merging.
 *
 * Given a driver's current route and a new passenger pickup/dropoff request,
 * determine whether the routes can be merged feasibly (time window constraints,
 * eq 7a/7b) and whether the merged cost satisfies the equilibrium test (eq 8).
 *
 * If feasible, writes the new anchor_points array to the trips table and returns
 * the updated anchor list.
 *
 * Anchor point schema stored in trips.anchor_points JSONB:
 *   [ { lat, lng, type: "pickup"|"dropoff", rider_id?, label? }, … ]
 */

import { Pool } from 'pg';
import { config } from '../config';

const pool = new Pool({ connectionString: config.databaseUrl });

// ─── Constants (He et al. 2014) ─────────────────────────────────────────────
const DELTA_T_SECONDS = 600;   // ±10 min feasibility window (eq 7a/7b)
const RHO             = 0.1;   // equilibrium threshold (eq 8)

// Scost weights used in scostForAnchorList (W1: avg detour, W3: extra distance)
const W1 = 0.5; const W3 = 0.1;

// ─── Types ───────────────────────────────────────────────────────────────────
export interface AnchorPoint {
  lat:      number;
  lng:      number;
  type:     'pickup' | 'dropoff';
  rider_id?: string;
  label?:   string;
  eta_offset_seconds?: number;   // seconds from trip departure_time
}

interface TripRow {
  trip_id:        string;
  driver_id:      string;
  origin_lat:     number;
  origin_lng:     number;
  destination_lat: number;
  destination_lng: number;
  departure_time: Date;
  seats_available: number;
  anchor_points:  AnchorPoint[];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
function haversine(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6_371_000;
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lng2 - lng1) * Math.PI) / 180;
  const a = Math.sin(Δφ / 2) ** 2 + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Rough ETA offset: assume 30 km/h average urban speed (Bay Area) */
function etaSeconds(distanceMeters: number): number {
  return (distanceMeters / (30_000 / 3600));
}

function scostForAnchorList(
  anchors: AnchorPoint[],
  driverOriginLat: number,
  driverOriginLng: number,
  directDistanceMeters: number
): number {
  let totalDetour = 0;
  let prev = { lat: driverOriginLat, lng: driverOriginLng };
  for (const a of anchors) {
    totalDetour += haversine(prev.lat, prev.lng, a.lat, a.lng);
    prev = a;
  }
  const m = anchors.filter(a => a.type === 'pickup').length;
  if (m === 0) return 0;
  return (
    W1 * (totalDetour / m / Math.max(directDistanceMeters, 1)) +
    W3 * (2 * (totalDetour - directDistanceMeters) / Math.max(directDistanceMeters, 1))
  );
}

// ─── Feasibility check for a specific anchor ordering (He et al. eq 7a / 7b) ──
/**
 * Returns true if the given anchor list does not push any existing passenger's
 * ETA beyond ±DELTA_T_SECONDS of their original committed ETA.
 * `newRiderId` anchors are excluded from the constraint check (they have no
 * pre-committed ETA).
 */
function isFeasibleOrdering(
  anchors: AnchorPoint[],
  driverOriginLat: number,
  driverOriginLng: number,
  newRiderId: string
): boolean {
  let cumulativeDist = 0;
  let prev = { lat: driverOriginLat, lng: driverOriginLng };

  for (const anchor of anchors) {
    cumulativeDist += haversine(prev.lat, prev.lng, anchor.lat, anchor.lng);
    prev = anchor;

    // Only check ETAs for existing passengers (not the new rider being inserted)
    if (anchor.rider_id && anchor.rider_id !== newRiderId && anchor.eta_offset_seconds !== undefined) {
      const newEta = etaSeconds(cumulativeDist);
      const drift = Math.abs(newEta - anchor.eta_offset_seconds);
      if (drift > DELTA_T_SECONDS) return false;
    }
  }
  return true;
}

// ─── Main merge function ──────────────────────────────────────────────────────

/**
 * Attempt to merge a new rider's pickup/dropoff into the trip's route.
 *
 * @param tripId     The driver's trip to merge into.
 * @param riderId    The new rider's user ID.
 * @param riderPickupLat / riderPickupLng   Rider's origin.
 * @param riderDropoffLat / riderDropoffLng Rider's destination.
 *
 * @returns Updated anchor points array, or null if merge is infeasible / fails equilibrium.
 */
export async function mergeRoute(
  tripId: string,
  riderId: string,
  riderPickupLat: number,
  riderPickupLng: number,
  riderDropoffLat: number,
  riderDropoffLng: number
): Promise<AnchorPoint[] | null> {
  // Load trip
  const result = await pool.query<TripRow>(
    `SELECT
       t.trip_id, t.driver_id,
       ST_Y(t.origin_point::geometry)      AS origin_lat,
       ST_X(t.origin_point::geometry)      AS origin_lng,
       ST_Y(t.destination_point::geometry) AS destination_lat,
       ST_X(t.destination_point::geometry) AS destination_lng,
       t.departure_time,
       t.seats_available,
       COALESCE(t.anchor_points, '[]'::jsonb) AS anchor_points
     FROM trips t
     WHERE t.trip_id = $1`,
    [tripId]
  );

  if (result.rows.length === 0) throw new Error(`Trip ${tripId} not found`);
  const trip = result.rows[0];

  const dp = haversine(trip.origin_lat, trip.origin_lng, trip.destination_lat, trip.destination_lng);

  const newPickup: AnchorPoint = {
    lat: riderPickupLat, lng: riderPickupLng,
    type: 'pickup', rider_id: riderId,
    label: 'Rider Pickup',
  };
  const newDropoff: AnchorPoint = {
    lat: riderDropoffLat, lng: riderDropoffLng,
    type: 'dropoff', rider_id: riderId,
    label: 'Rider Dropoff',
  };

  const currentAnchors: AnchorPoint[] = Array.isArray(trip.anchor_points) ? trip.anchor_points : [];
  const scostCurrent = scostForAnchorList(currentAnchors, trip.origin_lat, trip.origin_lng, dp);

  // ── Algorithm 3: try all valid pickup × dropoff insertion positions ─────────
  // For N existing anchors there are (N+1)*(N+2)/2 ordered (i,j) position pairs.
  // Pickup inserted at position i, dropoff at position j ≥ i.
  // Pick the ordering that minimises Scost while satisfying feasibility (eq 7a/7b).

  let bestMergedAnchors: AnchorPoint[] | null = null;
  let bestScostMerged = Infinity;

  const N = currentAnchors.length;
  for (let pickupIdx = 0; pickupIdx <= N; pickupIdx++) {
    for (let dropoffIdx = pickupIdx; dropoffIdx <= N; dropoffIdx++) {
      // Candidate ordering
      const candidate: AnchorPoint[] = [
        ...currentAnchors.slice(0, pickupIdx),
        { ...newPickup },
        ...currentAnchors.slice(pickupIdx, dropoffIdx),
        { ...newDropoff },
        ...currentAnchors.slice(dropoffIdx),
      ];

      // Compute ETA offsets for this candidate
      let cumDist = 0;
      let prev = { lat: trip.origin_lat, lng: trip.origin_lng };
      for (const anchor of candidate) {
        cumDist += haversine(prev.lat, prev.lng, anchor.lat, anchor.lng);
        anchor.eta_offset_seconds = etaSeconds(cumDist);
        prev = anchor;
      }

      // Feasibility: existing passengers' ETAs must not drift > DELTA_T_SECONDS
      if (!isFeasibleOrdering(candidate, trip.origin_lat, trip.origin_lng, riderId)) continue;

      const scostCandidate = scostForAnchorList(candidate, trip.origin_lat, trip.origin_lng, dp);
      if (scostCandidate < bestScostMerged) {
        bestScostMerged = scostCandidate;
        bestMergedAnchors = candidate;
      }
    }
  }

  if (!bestMergedAnchors) {
    console.log(`[route_merge] Trip ${tripId}: no feasible insertion position found for rider ${riderId}`);
    return null;
  }

  const mergedAnchors = bestMergedAnchors;
  const scostMerged   = bestScostMerged;

  // Equilibrium test (eq 8): only accept if improvement is material
  if (currentAnchors.length > 0) {
    if (scostMerged >= scostCurrent) {
      console.log(`[route_merge] Trip ${tripId}: merged Scost (${scostMerged.toFixed(3)}) ≥ current (${scostCurrent.toFixed(3)}), rejecting.`);
      return null;
    }
    if ((scostMerged - scostCurrent) / Math.max(scostCurrent, 0.0001) > -RHO) {
      console.log(`[route_merge] Trip ${tripId}: improvement below equilibrium threshold.`);
      return null;
    }
  }

  // Persist to DB
  await pool.query(
    `UPDATE trips SET anchor_points = $1::jsonb, updated_at = NOW() WHERE trip_id = $2`,
    [JSON.stringify(mergedAnchors), tripId]
  );

  console.log(`[route_merge] Trip ${tripId}: merged route with ${mergedAnchors.length} anchors (Scost ${scostCurrent.toFixed(3)} → ${scostMerged.toFixed(3)})`);
  return mergedAnchors;
}

/**
 * Fetch current anchor points for a trip (read-only).
 */
export async function getAnchorPoints(tripId: string): Promise<AnchorPoint[]> {
  const result = await pool.query<{ anchor_points: AnchorPoint[] }>(
    `SELECT COALESCE(anchor_points, '[]'::jsonb) AS anchor_points
     FROM trips WHERE trip_id = $1`,
    [tripId]
  );
  if (result.rows.length === 0) throw new Error(`Trip ${tripId} not found`);
  const raw = result.rows[0].anchor_points;
  return Array.isArray(raw) ? raw : [];
}
