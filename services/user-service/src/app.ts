import express, { Application } from 'express';
import path from 'path';
import userRoutes from './routes/user.routes';
import vehicleRoutes from './routes/vehicle.routes';
import { errorHandler, notFoundHandler, requestLogger, corsMiddleware, devCorsMiddleware } from '@lessgo/shared';
import { config } from './config';

const app: Application = express();

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS
if (config.env === 'development') {
  app.use(devCorsMiddleware);
} else {
  app.use(corsMiddleware);
}

// Request logging
app.use(requestLogger);

// Serve uploaded files
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'success',
    message: 'User Service is running',
    service: 'user-service',
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use('/users', userRoutes);
app.use('/vehicles', vehicleRoutes);

// 404 handler
app.use(notFoundHandler);

// Global error handler
app.use(errorHandler);

export default app;
