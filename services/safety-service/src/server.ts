import app from './app';
import { config } from './config';
import { initializeRedis } from './services/tracking.service';

const startServer = async () => {
  try {
    // Initialize Redis connection
    await initializeRedis();
    
    const server = app.listen(config.port, () => {
      console.log(`🛡️ Safety Service running on port ${config.port}`);
    });

    process.on('SIGTERM', () => server.close(() => process.exit(0)));
    process.on('SIGINT', () => server.close(() => process.exit(0)));
  } catch (error) {
    console.error('Failed to start Safety Service:', error);
    process.exit(1);
  }
};

startServer();
