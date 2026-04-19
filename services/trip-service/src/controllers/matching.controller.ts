/**
 * matching.controller.ts
 * ----------------------
 * Express controllers for the on-demand matching flow.
 *
 * Routes (added to trip.routes.ts):
 *   POST  /trips/request           – rider submits request, triggers matching
 *   GET   /trips/request/:id       – get status of pending request
 *   POST  /trips/:id/merge-route   – manually trigger route re-merge for a trip
 *   GET   /trips/:id/anchor-points – return anchor point list for a trip
 */

import { Request, Response } from 'express';
import { Pool } from 'pg';
import { config } from '../config';
import { matchRider, acceptMatch, declineMatch } from '../services/matching.service';
import { mergeRoute, getAnchorPoints } from '../services/route_merge.service';
import { mineFrequentRouteFromTrip, getFrequentRoutes } from '../services/frequent_route.service';

const pool = new Pool({ connectionString: config.databaseUrl });

// ── POST /trips/request ──────────────────────────────────────────────────────
/**
 * Rider submits a ride request (origin, destination, departure_time).
 * Immediately triggers the matching pipeline in the background.
 *
 * Body: { origin, destination, origin_lat, origin_lng,
 *         destination_lat, destination_lng, departure_time }
 */
export const requestTrip = async (req: Request, res: Response): Promise<void> => {
  try {
    console.log(`[matching] POST /trips/request received — user: ${(req as any).user?.userId ?? 'NONE'}`);

    const riderId = (req as any).user?.userId;
    if (!riderId) { res.status(401).json({ status: 'error', message: 'Unauthorized' }); return; }

    const { origin, destination, origin_lat, origin_lng,
            destination_lat, destination_lng, departure_time } = req.body;

    console.log(`[matching] requestTrip body:`, JSON.stringify(req.body));

    if (!origin || !destination || origin_lat === undefined || origin_lng === undefined ||
        destination_lat === undefined || destination_lng === undefined || !departure_time) {
      res.status(400).json({ status: 'error', message: 'Missing required fields' });
      return;
    }

    const result = await pool.query(
      `INSERT INTO trip_requests
         (rider_id, origin, destination, origin_lat, origin_lng,
          destination_lat, destination_lng, departure_time)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING request_id, status, created_at`,
      [riderId, origin, destination, origin_lat, origin_lng,
       destination_lat, destination_lng, departure_time]
    );

    const row = result.rows[0];
    console.log(`[matching] Trip request inserted: ${row.request_id}, triggering matchRider…`);

    // Trigger matching asynchronously — do not await so response is immediate
    setImmediate(() => {
      try {
        matchRider(row.request_id, 1).catch(err => {
          console.error(`[matching] [TRIGGER ERROR] matchRider promise rejected for ${row.request_id}:`, err);
          if (err instanceof Error) console.error(`[matching] [TRIGGER ERROR] stack:`, err.stack);
        });
      } catch (triggerErr) {
        console.error(`[matching] [TRIGGER ERROR] setImmediate threw synchronously:`, triggerErr);
        if (triggerErr instanceof Error) console.error(`[matching] [TRIGGER ERROR] stack:`, triggerErr.stack);
      }
    });

    res.status(201).json({
      status: 'success',
      message: 'Ride request submitted. Finding your driver…',
      data: {
        request_id:  row.request_id,
        status:      row.status,
        created_at:  row.created_at,
      },
    });
  } catch (err) {
    console.error(`[matching] [ERROR] requestTrip top-level catch:`, err);
    if (err instanceof Error) console.error(`[matching] [ERROR] stack:`, err.stack);
    res.status(500).json({ status: 'error', message: 'Internal server error in matching controller' });
  }
};

// ── GET /trips/request/:id ───────────────────────────────────────────────────
/**
 * Poll the status of a ride request.
 * Returns the matched trip details once status = 'matched'.
 */
export const getTripRequest = async (req: Request, res: Response): Promise<void> => {
  const riderId   = (req as any).user?.userId;
  const requestId = req.params.id;

  const result = await pool.query(
    `SELECT
       r.request_id, r.rider_id, r.status, r.origin, r.destination,
       r.departure_time, r.created_at, r.matched_trip_id,
       t.driver_id, t.seats_available,
       u.name AS driver_name, u.rating AS driver_rating,
       u.vehicle_info AS driver_vehicle_info
     FROM trip_requests r
     LEFT JOIN trips t ON t.trip_id = r.matched_trip_id
     LEFT JOIN users u ON u.user_id = t.driver_id
     WHERE r.request_id = $1`,
    [requestId]
  );

  if (result.rows.length === 0) {
    res.status(404).json({ status: 'error', message: 'Request not found' });
    return;
  }

  const row = result.rows[0];
  if (row.rider_id !== riderId) {
    res.status(403).json({ status: 'error', message: 'Forbidden' });
    return;
  }

  res.json({ status: 'success', data: row });
};

// ── POST /trips/:id/accept-match ─────────────────────────────────────────────
/**
 * Driver accepts an incoming match.
 * Body: { match_id }
 */
export const acceptRideMatch = async (req: Request, res: Response): Promise<void> => {
  const driverId = (req as any).user?.userId;
  const { match_id } = req.body;

  if (!match_id) { res.status(400).json({ status: 'error', message: 'match_id required' }); return; }

  await acceptMatch(match_id, driverId);
  res.json({ status: 'success', message: 'Match accepted' });
};

// ── POST /trips/:id/decline-match ────────────────────────────────────────────
/**
 * Driver declines an incoming match. Triggers retry with next candidate.
 * Body: { match_id }
 */
export const declineRideMatch = async (req: Request, res: Response): Promise<void> => {
  const driverId = (req as any).user?.userId;
  const { match_id } = req.body;

  if (!match_id) { res.status(400).json({ status: 'error', message: 'match_id required' }); return; }

  await declineMatch(match_id, driverId);
  res.json({ status: 'success', message: 'Match declined, retrying…' });
};

// ── POST /trips/:id/merge-route ──────────────────────────────────────────────
/**
 * Manually trigger route re-merge for a new rider into an existing trip.
 * Body: { rider_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng }
 */
export const triggerMergeRoute = async (req: Request, res: Response): Promise<void> => {
  const tripId = req.params.id;
  const { rider_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng } = req.body;

  if (!rider_id || pickup_lat === undefined || pickup_lng === undefined ||
      dropoff_lat === undefined || dropoff_lng === undefined) {
    res.status(400).json({ status: 'error', message: 'Missing merge parameters' });
    return;
  }

  const anchors = await mergeRoute(
    tripId, rider_id,
    parseFloat(pickup_lat), parseFloat(pickup_lng),
    parseFloat(dropoff_lat), parseFloat(dropoff_lng)
  );

  if (anchors === null) {
    res.status(409).json({
      status: 'error',
      message: 'Route merge infeasible (time window or equilibrium constraint violated)',
    });
    return;
  }

  res.json({
    status: 'success',
    message: 'Route merged successfully',
    data: { trip_id: tripId, anchor_points: anchors },
  });
};

// ── GET /trips/:id/anchor-points ─────────────────────────────────────────────
/**
 * Return the current anchor points for a trip (for iOS map stitching).
 */
export const fetchAnchorPoints = async (req: Request, res: Response): Promise<void> => {
  const tripId = req.params.id;
  const anchors = await getAnchorPoints(tripId);

  res.json({
    status: 'success',
    data: { trip_id: tripId, anchor_points: anchors },
  });
};

// ── GET /trips/driver/:driverId/frequent-routes ──────────────────────────────
/**
 * Return frequent-route segments mined from a driver's completed trip history.
 * Each segment includes GPS center coordinates for both origin and destination
 * grid cells so the iOS client can render them as a dashed polyline.
 */
export const getDriverFrequentRoutes = async (req: Request, res: Response): Promise<void> => {
  const driverId = req.params.driverId;
  if (!driverId) {
    res.status(400).json({ status: 'error', message: 'driverId required' });
    return;
  }

  const routes = await getFrequentRoutes(driverId);
  res.json({ status: 'success', data: { driver_id: driverId, routes } });
};

// ── POST /trips/debug-seed-history ───────────────────────────────────────────
/**
 * Development-only: insert completed historical trips directly into the `trips`
 * table, bypassing geocoding and overlap checks, then run frequent-route mining
 * on each so the He et al. Stage 1 candidate set reflects historical patterns.
 *
 * Body: {
 *   user_id: string,
 *   trips: Array<{
 *     origin_lat, origin_lng, destination_lat, destination_lng,
 *     origin_label, destination_label,   // optional display strings
 *     departure_time                      // ISO 8601
 *   }>
 * }
 */
export const seedTripHistory = async (req: Request, res: Response): Promise<void> => {
  if (process.env.NODE_ENV === 'production') {
    res.status(403).json({ status: 'error', message: 'Not available in production' });
    return;
  }

  const { user_id, trips } = req.body as {
    user_id: string;
    trips: Array<{
      origin_lat: number; origin_lng: number;
      destination_lat: number; destination_lng: number;
      origin_label?: string; destination_label?: string;
      departure_time: string;
    }>;
  };

  if (!user_id || !Array.isArray(trips) || trips.length === 0) {
    res.status(400).json({ status: 'error', message: 'user_id and non-empty trips[] required' });
    return;
  }

  const insertedIds: string[] = [];

  for (const t of trips) {
    const {
      origin_lat, origin_lng, destination_lat, destination_lng,
      origin_label, destination_label, departure_time,
    } = t;

    const result = await pool.query<{ trip_id: string }>(
      `INSERT INTO trips
         (driver_id, origin, destination,
          origin_point, destination_point,
          departure_time, seats_available, status)
       VALUES
         ($1, $2, $3,
          ST_SetSRID(ST_MakePoint($4, $5), 4326),
          ST_SetSRID(ST_MakePoint($6, $7), 4326),
          $8, 1, 'completed')
       RETURNING trip_id`,
      [
        user_id,
        origin_label      ?? 'Sim Origin',
        destination_label ?? 'Sim Destination',
        Number(origin_lng),      Number(origin_lat),
        Number(destination_lng), Number(destination_lat),
        departure_time,
      ]
    );

    const tripId = result.rows[0].trip_id;
    insertedIds.push(tripId);

    // Feed frequent-route mining so Stage 1 history is populated
    try {
      await mineFrequentRouteFromTrip(tripId);
    } catch (err) {
      console.warn(`[debug-seed] freq-route mining failed for ${tripId}:`, (err as Error).message);
    }
  }

  res.status(201).json({
    status: 'success',
    message: `Seeded ${insertedIds.length} completed trip(s)`,
    data: { trip_ids: insertedIds },
  });
};
