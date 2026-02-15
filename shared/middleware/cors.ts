import cors, { CorsOptions } from 'cors';

/**
 * CORS configuration
 * Allows requests from frontend origins
 */
const allowedOrigins = [
  'http://localhost:3000', // React development server
  'http://localhost:3001', // Alternative React port
  'http://localhost:19006', // React Native Expo
  'http://localhost:8081', // React Native Metro bundler
];

// Add production origins from environment variable
if (process.env.FRONTEND_URL) {
  allowedOrigins.push(process.env.FRONTEND_URL);
}

const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps, curl, Postman)
    if (!origin) {
      return callback(null, true);
    }

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      console.warn(`⚠️  CORS blocked origin: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true, // Allow cookies and authorization headers
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Correlation-ID',
    'X-Request-ID',
  ],
  exposedHeaders: ['X-Correlation-ID'], // Allow client to read correlation ID
  maxAge: 86400, // Cache preflight request for 24 hours
};

/**
 * CORS middleware with configured options
 */
export const corsMiddleware = cors(corsOptions);

/**
 * Development CORS - allows all origins
 * Only use in development/testing
 */
export const devCorsMiddleware = cors({
  origin: '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
});
