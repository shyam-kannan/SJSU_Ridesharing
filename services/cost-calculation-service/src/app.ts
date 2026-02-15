import express from 'express';
import cors from 'cors';
import axios from 'axios';

const app = express();
app.use(express.json());
app.use(cors());

// Configuration
const BASE_PRICE = 5.0;
const PRICE_PER_MILE = 0.5;
const ROUTING_SERVICE_URL = process.env.ROUTING_SERVICE_URL || 'http://localhost:8002';

/**
 * TODO: ADVANCED PRICING MODEL INTEGRATION POINT
 *
 * This is a simple placeholder algorithm. To integrate advanced pricing:
 *
 * 1. Replace calculateCost() with a call to your ML model API
 * 2. Consider factors like:
 *    - Time of day (surge pricing)
 *    - Historical demand patterns
 *    - Driver vehicle efficiency (MPG)
 *    - Route complexity and traffic
 *    - Seasonal patterns
 *    - User loyalty/discounts
 *
 * Example integration:
 *
 * const response = await axios.post('http://ml-pricing-service/predict', {
 *   origin, destination, num_riders, departure_time,
 *   historical_demand, traffic_data, vehicle_mpg
 * });
 * return response.data.predicted_price;
 */

app.get('/health', (req, res) => {
  res.json({ status: 'success', message: 'Cost Calculation Service is running' });
});

app.post('/cost/calculate', async (req, res) => {
  try {
    const { origin, destination, num_riders, trip_id } = req.body;

    if (!origin || !destination || !num_riders) {
      return res.status(400).json({
        status: 'error',
        message: 'origin, destination, and num_riders are required',
      });
    }

    // Get distance from Routing Service
    let distance_miles = 10; // Default fallback

    try {
      const routeResponse = await axios.post(`${ROUTING_SERVICE_URL}/route/calculate`, {
        origin,
        destination,
      });
      distance_miles = routeResponse.data.data.distance_miles || 10;
    } catch (error) {
      console.warn('Routing service unavailable, using default distance:', error);
    }

    // Simple pricing formula
    // TODO: Replace with advanced pricing model (see comment above)
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

const PORT = process.env.COST_SERVICE_PORT || 3009;
app.listen(PORT, () => {
  console.log(`💰 Cost Calculation Service running on port ${PORT}`);
  console.log('⚠️  Using simple placeholder algorithm - see code comments for ML integration');
});

export default app;
