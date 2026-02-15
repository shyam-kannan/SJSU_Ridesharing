import app from './app';
import { config } from './config';

const server = app.listen(config.port, () => {
  console.log(`💳 Payment Service running on port ${config.port}`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
export default server;
