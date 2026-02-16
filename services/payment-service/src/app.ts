import express from 'express';
import paymentRoutes from './routes/payment.routes';
import { errorHandler, notFoundHandler, requestLogger, devCorsMiddleware } from '@lessgo/shared';
import { config } from './config';

const app = express();

app.use(express.json());
app.use(devCorsMiddleware);
app.use(requestLogger);

app.get('/health', (req, res) => {
  res.json({ status: 'success', message: 'Payment Service is running', service: 'payment-service' });
});

app.use('/payments', paymentRoutes);
app.use(notFoundHandler);
app.use(errorHandler);

export default app;
