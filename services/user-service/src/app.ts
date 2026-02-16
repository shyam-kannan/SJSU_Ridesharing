import express, { Application } from 'express';
import userRoutes from './routes/user.routes';
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

// 404 handler
app.use(notFoundHandler);

// Global error handler
app.use(errorHandler);

export default app;
