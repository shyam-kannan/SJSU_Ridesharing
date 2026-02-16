import app from './app';

const PORT = process.env.NOTIFICATION_SERVICE_PORT || 3006;

const server = app.listen(PORT, () => {
  console.log(`
  ========================================
  Notification Service is running (STUB)
  ========================================
  Port: ${PORT}
  URL: http://localhost:${PORT}
  Health Check: http://localhost:${PORT}/health
  ========================================
  `);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received: closing server');
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log('SIGINT received: closing server');
  server.close(() => process.exit(0));
});

export default server;
