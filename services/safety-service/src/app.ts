import express, { Application } from 'express';
import { errorHandler, notFoundHandler, requestLogger, corsMiddleware, devCorsMiddleware } from '@lessgo/shared';
import safetyRoutes from './routes/safety.routes';
import { config } from './config';

const app: Application = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(config.env === 'development' ? devCorsMiddleware : corsMiddleware);
app.use(requestLogger);

app.get('/health', (req, res) => {
  res.json({ 
    status: 'success', 
    message: 'Safety Service is running', 
    service: 'safety-service', 
    timestamp: new Date().toISOString() 
  });
});

app.use('/', safetyRoutes);

app.use(notFoundHandler);
app.use(errorHandler);

export default app;
