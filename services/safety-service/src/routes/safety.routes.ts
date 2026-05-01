import { Router } from 'express';
import { body, param } from 'express-validator';
import { validateRequest, authenticateToken } from '@lessgo/shared';
import * as safetyController from '../controllers/safety.controller';

const router = Router();

// Temporarily bypassing token auth for testing, but in production this should have authenticateToken
// For now, let's keep it simple or require it based on global config

router.post(
  '/rides/:ride_id/start',
  // authenticateToken,
  [
    param('ride_id').isUUID().withMessage('Valid ride_id UUID is required'),
    body('planned_route').isString().withMessage('planned_route must be an encoded polyline string')
  ],
  validateRequest,
  safetyController.startMonitoring
);

router.post(
  '/rides/:ride_id/end',
  // authenticateToken,
  [
    param('ride_id').isUUID().withMessage('Valid ride_id UUID is required')
  ],
  validateRequest,
  safetyController.stopMonitoring
);

router.post(
  '/rides/:ride_id/location',
  // authenticateToken,
  [
    param('ride_id').isUUID().withMessage('Valid ride_id UUID is required'),
    body('coordinates.lat').isFloat({ min: -90, max: 90 }).withMessage('Valid latitude is required'),
    body('coordinates.lng').isFloat({ min: -180, max: 180 }).withMessage('Valid longitude is required'),
    body('speed').isFloat({ min: 0 }).withMessage('Speed must be a positive number'),
    body('timestamp').optional().isISO8601().withMessage('Invalid timestamp')
  ],
  validateRequest,
  safetyController.processLocationUpdate
);

router.get(
  '/rides/:ride_id/anomalies',
  // authenticateToken,
  [
    param('ride_id').isUUID().withMessage('Valid ride_id UUID is required')
  ],
  validateRequest,
  safetyController.getAnomalies
);

router.patch(
  '/anomalies/:anomaly_id/acknowledge',
  // authenticateToken,
  [
    param('anomaly_id').isUUID().withMessage('Valid anomaly_id UUID is required')
  ],
  validateRequest,
  safetyController.acknowledgeAnomaly
);

export default router;
