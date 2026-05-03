import app from './app';
import { config } from './config';

const startServer = async () => {
  try {
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
