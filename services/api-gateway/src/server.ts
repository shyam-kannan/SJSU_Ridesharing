import app from './app';

const PORT = process.env.API_GATEWAY_PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`
  ========================================
  🌐 API Gateway is running
  ========================================
  Port: ${PORT}
  URL: http://localhost:${PORT}
  Health Check: http://localhost:${PORT}/health
  API Base: http://localhost:${PORT}/api
  ========================================
  `);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));

export default server;
