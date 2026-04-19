/**
 * frequent_route.service.ts
 * -------------------------
 * He et al. 2014, Algorithm 1 – frequent route mining from completed trip history.
 *
 * Runs as a lightweight post-trip background job:
 *   1. Assign trip endpoints to Bay Area 16×16 grid zones (500 m × 500 m cells).
 *   2. Upsert into frequent_routes with incremented frequency.
 *   3. Recompute edge_score (Se) and route_score (Sr) for the affected zone pair.
 *
 * Thresholds (He et al. §4):
 *   alpha = 2  → qualified edge  (f(e) > alpha)
 *   beta  = 2  → frequent edge   (Se > beta, relative to all qualified edges)
 *   gamma = 0.8 → qualified route (Sr > gamma)
 */

import { Pool } from 'pg';
import { config } from '../config';

const pool = new Pool({ connectionString: config.databaseUrl });

// ─── Grid constants ───────────────────────────────────────────────────────────
// Tighter SJSU-area bounding box, 128×128 grid.
// Cell size ≈ 0.58°/128 ≈ 0.00453°lat ≈ 503 m,  0.60°/128 ≈ 0.00469°lng ≈ 415 m.
// Verified: North zone (37.3400,-121.8780) → zone 6724; SJSU (37.3352,-121.8811)
// → zone 6596.  Different cells, ~600 m apart. ✓
const LAT_MIN = 37.10; const LAT_MAX = 37.68;   // 0.58° span
const LNG_MIN = -122.20; const LNG_MAX = -121.60; // 0.60° span
const GRID_ROWS = 128; const GRID_COLS = 128;

// He et al. thresholds
const ALPHA = 2;   // qualified edge frequency threshold (f(e) > ALPHA)

function latLngToZone(lat: number, lng: number): number {
  const clampedLat = Math.max(LAT_MIN, Math.min(LAT_MAX, lat));
  const clampedLng = Math.max(LNG_MIN, Math.min(LNG_MAX, lng));

  const row = Math.min(
    Math.floor((clampedLat - LAT_MIN) / (LAT_MAX - LAT_MIN) * GRID_ROWS),
    GRID_ROWS - 1
  );
  const col = Math.min(
    Math.floor((clampedLng - LNG_MIN) / (LNG_MAX - LNG_MIN) * GRID_COLS),
    GRID_COLS - 1
  );
  return row * GRID_COLS + col;  // 0–16383
}

/**
 * Mine frequent route data from a single completed trip.
 * Called automatically by updateTripState when status → 'completed'.
 *
 * @param tripId The completed trip's UUID.
 */
export async function mineFrequentRouteFromTrip(tripId: string): Promise<void> {
  try {
    const result = await pool.query(
      `SELECT
         ST_Y(origin_point::geometry)      AS origin_lat,
         ST_X(origin_point::geometry)      AS origin_lng,
         ST_Y(destination_point::geometry) AS destination_lat,
         ST_X(destination_point::geometry) AS destination_lng,
         departure_time
       FROM trips WHERE trip_id = $1`,
      [tripId]
    );

    if (result.rows.length === 0) return;
    const row = result.rows[0];

    const originZone = latLngToZone(row.origin_lat, row.origin_lng);
    const destZone   = latLngToZone(row.destination_lat, row.destination_lng);
    const timeBin    = new Date(row.departure_time).getHours();

    // Upsert: increment frequency, recompute scores
    await pool.query(
      `INSERT INTO frequent_routes (origin_zone, destination_zone, time_bin, frequency, edge_score, route_score, last_seen)
       VALUES ($1, $2, $3, 1, 0, 0, NOW())
       ON CONFLICT (origin_zone, destination_zone, time_bin)
       DO UPDATE SET
         frequency  = frequent_routes.frequency + 1,
         last_seen  = NOW(),
         updated_at = NOW()`,
      [originZone, destZone, timeBin]
    );

    // Recompute edge_score (Se) and route_score (Sr) for this zone pair
    await recomputeScores(originZone, destZone, timeBin);

    console.log(`[frequent_route] Mined trip ${tripId}: zone ${originZone}→${destZone} t=${timeBin}`);
  } catch (err) {
    console.error(`[frequent_route] Error mining trip ${tripId}:`, err);
  }
}

// ─── Zone → GPS center (reverse mapping) ────────────────────────────────────
export function zoneToCenter(zone: number): { lat: number; lng: number } {
  const row = Math.floor(zone / GRID_COLS);
  const col = zone % GRID_COLS;
  const lat = LAT_MIN + (row + 0.5) * (LAT_MAX - LAT_MIN) / GRID_ROWS;
  const lng = LNG_MIN + (col + 0.5) * (LNG_MAX - LNG_MIN) / GRID_COLS;
  return { lat, lng };
}

// ─── Types ───────────────────────────────────────────────────────────────────
export interface FrequentRouteEntry {
  originZone:   number;
  destZone:     number;
  timeBin:      number;
  frequency:    number;
  routeScore:   number;
  originCenter: { lat: number; lng: number };
  destCenter:   { lat: number; lng: number };
}

/**
 * Return the frequent-route segments mined from a specific driver's
 * completed trip history.  Each entry includes the GPS center of both
 * the origin and destination grid cells so the iOS client can render
 * the route polyline without further conversion.
 */
export async function getFrequentRoutes(driverId: string): Promise<FrequentRouteEntry[]> {
  // 1. Fetch driver's completed trips (origin/destination lat-lng)
  const tripResult = await pool.query<{
    origin_lat: number; origin_lng: number;
    dest_lat: number;   dest_lng: number;
  }>(
    `SELECT
       ST_Y(origin_point::geometry)      AS origin_lat,
       ST_X(origin_point::geometry)      AS origin_lng,
       ST_Y(destination_point::geometry) AS dest_lat,
       ST_X(destination_point::geometry) AS dest_lng
     FROM trips
     WHERE driver_id = $1 AND status = 'completed'
     LIMIT 100`,
    [driverId]
  );

  if (tripResult.rows.length === 0) return [];

  // 2. Compute distinct zone pairs in JS
  const zonePairMap = new Map<string, { originZone: number; destZone: number }>();
  for (const row of tripResult.rows) {
    const oz = latLngToZone(row.origin_lat, row.origin_lng);
    const dz = latLngToZone(row.dest_lat, row.dest_lng);
    if (oz === dz) continue;  // skip same-cell trips (sub-cell distance)
    const key = `${oz}_${dz}`;
    if (!zonePairMap.has(key)) zonePairMap.set(key, { originZone: oz, destZone: dz });
  }

  const pairs = [...zonePairMap.values()];
  if (pairs.length === 0) return [];

  // 3. Fetch scores for those zone pairs from the frequent_routes table
  const valueList = pairs.map(p => `(${p.originZone}, ${p.destZone})`).join(', ');
  const freqResult = await pool.query<{
    origin_zone: number; destination_zone: number;
    time_bin: number; frequency: number; route_score: number;
  }>(
    `SELECT origin_zone, destination_zone, time_bin, frequency, route_score
     FROM frequent_routes
     WHERE (origin_zone, destination_zone) IN (${valueList})
     ORDER BY route_score DESC`
  );

  // Fallback: for pairs not yet in frequent_routes (not mined yet), still return them
  const minedKeys = new Set(freqResult.rows.map(r => `${r.origin_zone}_${r.destination_zone}`));
  const unminedEntries: FrequentRouteEntry[] = pairs
    .filter(p => !minedKeys.has(`${p.originZone}_${p.destZone}`))
    .map(p => ({
      originZone:   p.originZone,
      destZone:     p.destZone,
      timeBin:      -1,
      frequency:    1,
      routeScore:   0,
      originCenter: zoneToCenter(p.originZone),
      destCenter:   zoneToCenter(p.destZone),
    }));

  const minedEntries: FrequentRouteEntry[] = freqResult.rows.map(r => ({
    originZone:   r.origin_zone,
    destZone:     r.destination_zone,
    timeBin:      r.time_bin,
    frequency:    r.frequency,
    routeScore:   r.route_score,
    originCenter: zoneToCenter(r.origin_zone),
    destCenter:   zoneToCenter(r.destination_zone),
  }));

  return [...minedEntries, ...unminedEntries];
}

/**
 * Recompute Se (edge_score) and Sr (route_score) for a given zone/time pair.
 *
 * Se = f(e) / max_frequency_in_same_time_bin   (normalized)
 * Sr = Se / (1 + |routes sharing this zone pair|)  (simplified from He et al.)
 *
 * Only edges with f(e) > ALPHA qualify; Se > BETA qualifies as frequent.
 */
async function recomputeScores(
  originZone: number,
  destZone: number,
  timeBin: number
): Promise<void> {
  // Get max frequency in this time_bin (normalization denominator)
  const maxResult = await pool.query<{ max_freq: string }>(
    `SELECT MAX(frequency) AS max_freq FROM frequent_routes WHERE time_bin = $1`,
    [timeBin]
  );
  const maxFreq = parseInt(maxResult.rows[0]?.max_freq ?? '1', 10) || 1;

  // Count routes sharing this origin zone (for Sr denominator)
  const routeShareResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*) AS count FROM frequent_routes
     WHERE origin_zone = $1 AND time_bin = $2 AND frequency > $3`,
    [originZone, timeBin, ALPHA]
  );
  const sharedRoutes = parseInt(routeShareResult.rows[0]?.count ?? '1', 10) || 1;

  // Fetch this edge's frequency
  const edgeResult = await pool.query<{ frequency: number }>(
    `SELECT frequency FROM frequent_routes
     WHERE origin_zone = $1 AND destination_zone = $2 AND time_bin = $3`,
    [originZone, destZone, timeBin]
  );
  if (edgeResult.rows.length === 0) return;

  const freq   = edgeResult.rows[0].frequency;
  const edgeScore  = freq > ALPHA ? freq / maxFreq : 0;
  const routeScore = edgeScore > 0 ? edgeScore / (1 + sharedRoutes) : 0;

  await pool.query(
    `UPDATE frequent_routes
     SET edge_score = $1, route_score = $2, updated_at = NOW()
     WHERE origin_zone = $3 AND destination_zone = $4 AND time_bin = $5`,
    [edgeScore, routeScore, originZone, destZone, timeBin]
  );
}
