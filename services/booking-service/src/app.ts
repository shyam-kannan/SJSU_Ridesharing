import express, { Application } from 'express';
import bookingRoutes from './routes/booking.routes';
import { errorHandler, notFoundHandler, requestLogger, corsMiddleware, devCorsMiddleware } from '@lessgo/shared';
import { config } from './config';

const app: Application = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(config.env === 'development' ? devCorsMiddleware : corsMiddleware);
app.use(requestLogger);

app.get('/health', (req, res) => {
  res.json({ status: 'success', message: 'Booking Service is running', service: 'booking-service', timestamp: new Date().toISOString() });
});

app.use('/bookings', bookingRoutes);
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
