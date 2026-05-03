import { Request, Response } from 'express';
import { successResponse, errorResponse } from '@lessgo/shared';
import * as trackingService from '../services/tracking.service';
import * as anomalyService from '../services/anomaly.service';
import { query } from '@lessgo/shared';

/**
 * Begin monitoring a ride
 * body: { planned_route: "<encoded_polyline>" }
 */
export const startMonitoring = async (req: Request, res: Response) => {
  try {
    const { ride_id } = req.params;
    const { planned_route } = req.body;

    await trackingService.startTracking(ride_id, planned_route);

    return successResponse(res, { ride_id }, 'Started monitoring ride');
  } catch (error: any) {
    console.error('Error starting monitoring:', error);
    return errorResponse(res, 'Failed to start monitoring', 500, error.message);
  }
};

/**
 * Stop monitoring a ride
 */
export const stopMonitoring = async (req: Request, res: Response) => {
  try {
    const { ride_id } = req.params;

    await trackingService.stopTracking(ride_id);

    return successResponse(res, { ride_id }, 'Stopped monitoring ride');
  } catch (error: any) {
    console.error('Error stopping monitoring:', error);
    return errorResponse(res, 'Failed to stop monitoring', 500, error.message);
  }
};

/**
 * Receive a live location update
 * body: { coordinates: { lat, lng }, speed, timestamp? }
 */
export const processLocationUpdate = async (req: Request, res: Response) => {
  try {
    const { ride_id } = req.params;
    const { coordinates, speed, timestamp } = req.body;
    const ts = timestamp ? new Date(timestamp) : new Date();

    // The anomaly service will handle detecting any issues
    const anomalies = await anomalyService.checkAnomalies(ride_id, coordinates, speed, ts);

    return successResponse(res, { anomalies_detected: anomalies.length, anomalies }, 'Location processed');
  } catch (error: any) {
    if (error.message === 'Ride not found or not currently tracked') {
      return errorResponse(res, error.message, 404);
    }
    console.error('Error processing location:', error);
    return errorResponse(res, 'Failed to process location update', 500, error.message);
  }
};

/**
 * Retrieve all anomaly events for a ride
 */
export const getAnomalies = async (req: Request, res: Response) => {
  try {
    const { ride_id } = req.params;

    const result = await query(
      'SELECT * FROM anomaly_events WHERE trip_id = $1 ORDER BY detected_at DESC',
      [ride_id]
    );

    return successResponse(res, { anomalies: result.rows }, 'Anomalies retrieved');
  } catch (error: any) {
    console.error('Error getting anomalies:', error);
    return errorResponse(res, 'Failed to retrieve anomalies', 500, error.message);
  }
};

/**
 * Rider acknowledges or dismisses an anomaly alert
 */
export const acknowledgeAnomaly = async (req: Request, res: Response) => {
  try {
    const { anomaly_id } = req.params;

    const result = await query(
      'UPDATE anomaly_events SET acknowledged = true, acknowledged_at = current_timestamp WHERE anomaly_id = $1 RETURNING *',
      [anomaly_id]
    );

    if (result.rowCount === 0) {
      return errorResponse(res, 'Anomaly not found', 404);
    }

    return successResponse(res, { anomaly: result.rows[0] }, 'Anomaly acknowledged');
  } catch (error: any) {
    console.error('Error acknowledging anomaly:', error);
    return errorResponse(res, 'Failed to acknowledge anomaly', 500, error.message);
  }
};
