import express, { Request, Response } from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import rateLimit from 'express-rate-limit';
import cors from 'cors';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

dotenv.config();

const app = express();

// CORS Configuration
app.use(cors({
  origin: '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Correlation-ID'],
}));

// NOTE: express.json() is intentionally NOT added here.
// The gateway is a pure proxy — it must forward raw request bytes to each
// microservice. Parsing the body here consumes the stream and causes
// http-proxy-middleware to forward an empty body, resulting in ECONNRESET.
// Each microservice parses its own request bodies.

// Service URLs — use 127.0.0.1 to avoid IPv6 (::1) resolution issues on macOS
const SERVICES = {
  auth: process.env.AUTH_SERVICE_URL || 'http://127.0.0.1:3001',
  user: process.env.USER_SERVICE_URL || 'http://127.0.0.1:3002',
  trip: process.env.TRIP_SERVICE_URL || 'http://127.0.0.1:3003',
  booking: process.env.BOOKING_SERVICE_URL || 'http://127.0.0.1:3004',
  payment: process.env.PAYMENT_SERVICE_URL || 'http://127.0.0.1:3005',
  notification: process.env.NOTIFICATION_SERVICE_URL || 'http://127.0.0.1:3006',
  grouping: process.env.GROUPING_SERVICE_URL || 'http://127.0.0.1:8001',
  routing: process.env.ROUTING_SERVICE_URL || 'http://127.0.0.1:8002',
  cost: process.env.COST_SERVICE_URL || 'http://127.0.0.1:3009',
};

// Rate Limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  message: { status: 'error', message: 'Too many requests, please try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api', limiter);

// Request Logging Middleware
app.use((req, res, next) => {
  const correlationId = req.headers['x-correlation-id'] || `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  req.headers['x-correlation-id'] = correlationId.toString();
  res.setHeader('x-correlation-id', correlationId.toString());

  console.log(`📨 [${new Date().toISOString()}] ${req.method} ${req.path} [${correlationId}]`);
  next();
});

// JWT Validation Middleware (for protected routes)
const jwtMiddleware = (req: Request, res: Response, next: Function) => {
  // NOTE: mounted at app.use('/api', ...) so req.path is WITHOUT the /api prefix.
  // A request to /api/auth/register arrives here as /auth/register.
  const publicPaths = ['/auth/register', '/auth/login', '/auth/refresh'];

  console.log(`[JWT] path="${req.path}" | isPublic=${publicPaths.some(p => req.path.startsWith(p))}`);

  if (publicPaths.some(path => req.path.startsWith(path))) {
    console.log(`[JWT] Skipping auth for public path: ${req.path}`);
    return next();
  }

  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token && req.path.startsWith('/trips') && req.method === 'GET') {
    // Allow public trip viewing
    return next();
  }

  if (!token) {
    return res.status(401).json({ status: 'error', message: 'Access token required' });
  }

  try {
    const jwtSecret = process.env.JWT_SECRET || 'default-secret';
    jwt.verify(token, jwtSecret);
    next();
  } catch (error) {
    return res.status(403).json({ status: 'error', message: 'Invalid or expired token' });
  }
};

app.use('/api', jwtMiddleware);

// Health Check — uses express.json() locally for this one route only
app.get('/health', express.json(), (req, res) => {
  res.json({
    status: 'success',
    message: 'API Gateway is running',
    timestamp: new Date().toISOString(),
    services: SERVICES,
  });
});

// Proxy Configuration
const proxyOptions = {
  changeOrigin: true,
  proxyTimeout: 15000,
  timeout: 15000,
  logLevel: 'warn' as const,
  onError: (err: Error, req: Request, res: Response) => {
    console.error(`❌ Proxy error for ${req.path}: ${err.message}`);
    res.status(502).json({
      status: 'error',
      message: 'Service temporarily unavailable',
    });
  },
};

// Route to Services
app.use('/api/auth', createProxyMiddleware({
  target: SERVICES.auth,
  pathRewrite: { '^/api/auth': '/auth' },
  ...proxyOptions,
}));

app.use('/api/users', createProxyMiddleware({
  target: SERVICES.user,
  pathRewrite: { '^/api/users': '/users' },
  ...proxyOptions,
}));

app.use('/api/trips', createProxyMiddleware({
  target: SERVICES.trip,
  pathRewrite: { '^/api/trips': '/trips' },
  ...proxyOptions,
}));

app.use('/api/bookings', createProxyMiddleware({
  target: SERVICES.booking,
  pathRewrite: { '^/api/bookings': '/bookings' },
  ...proxyOptions,
}));

app.use('/api/payments', createProxyMiddleware({
  target: SERVICES.payment,
  pathRewrite: { '^/api/payments': '/payments' },
  ...proxyOptions,
}));

app.use('/api/notifications', createProxyMiddleware({
  target: SERVICES.notification,
  pathRewrite: { '^/api/notifications': '/notifications' },
  ...proxyOptions,
}));

app.use('/api/group', createProxyMiddleware({
  target: SERVICES.grouping,
  pathRewrite: { '^/api/group': '/group' },
  ...proxyOptions,
}));

app.use('/api/route', createProxyMiddleware({
  target: SERVICES.routing,
  pathRewrite: { '^/api/route': '/route' },
  ...proxyOptions,
}));

app.use('/api/cost', createProxyMiddleware({
  target: SERVICES.cost,
  pathRewrite: { '^/api/cost': '/cost' },
  ...proxyOptions,
}));

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: `Route ${req.method} ${req.path} not found`,
  });
});

export default app;
