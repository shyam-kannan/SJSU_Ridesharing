import express, { Application } from 'express';
import cors from 'cors';
import axios from 'axios';

const app: Application = express();
app.use(express.json());
app.use(cors());

// Configuration
const BASE_PRICE = 5.0;
const PRICE_PER_MILE = 0.5;
const ROUTING_SERVICE_URL = process.env.ROUTING_SERVICE_URL || 'http://localhost:8002';

// Health check
app.get('/health', (_req, res) => {
  res.json({
    status: 'success',
    message: 'Cost Calculation Service is running',
    service: 'cost-calculation-service',
    timestamp: new Date().toISOString(),
  });
});

// Calculate cost for a trip
app.post('/cost/calculate', async (req, res) => {
  try {
    const { origin, destination, num_riders, trip_id } = req.body;

    if (!origin || !destination || !num_riders) {
      res.status(400).json({
        status: 'error',
        message: 'origin, destination, and num_riders are required',
      });
      return;
    }

    // Get distance from Routing Service
    let distance_miles = 10; // Default fallback

    try {
      const routeResponse = await axios.post(`${ROUTING_SERVICE_URL}/route/calculate`, {
        origin,
        destination,
      });
      distance_miles = routeResponse.data.data.distance_miles || 10;
    } catch {
      console.warn('Routing service unavailable, using default distance of 10 miles');
    }

    // Simple pricing formula: base + (distance * rate) / riders
    const total_trip_cost = BASE_PRICE + distance_miles * PRICE_PER_MILE;
    const price_per_rider = total_trip_cost / num_riders;

    const breakdown = {
      base_price: BASE_PRICE,
      distance_miles: parseFloat(distance_miles.toFixed(2)),
      price_per_mile: PRICE_PER_MILE,
      total_trip_cost: parseFloat(total_trip_cost.toFixed(2)),
      price_per_rider: parseFloat(price_per_rider.toFixed(2)),
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
    res.status(500).json({
      status: 'error',
      message: 'Failed to calculate cost',
    });
  }
});

export default app;
