import app from './app';

const PORT = process.env.API_GATEWAY_PORT || 3000;
const BIND_HOST = process.env.HOST || '0.0.0.0';
const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL;

const server = app.listen(PORT, BIND_HOST, () => {
  const localBase = `http://${BIND_HOST}:${PORT}`;
  const externalBase = PUBLIC_BASE_URL || 'N/A (set PUBLIC_BASE_URL to show external endpoint)';

  console.log(`
  ========================================
  🌐 API Gateway is running
  ========================================
  Bind: ${BIND_HOST}:${PORT}
  Port: ${PORT}
  Local URL: ${localBase}
  Local Health Check: ${localBase}/health
  Local API Base: ${localBase}/api
  Public URL: ${externalBase}
  ========================================
  `);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT', () => server.close(() => process.exit(0)));

export default server;
