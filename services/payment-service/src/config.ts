import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: process.env.PAYMENT_SERVICE_PORT || 3005,
  env: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL,
  stripeSecretKey: process.env.STRIPE_SECRET_KEY,
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
};

if (!config.databaseUrl) throw new Error('DATABASE_URL required');
if (!config.stripeSecretKey) throw new Error('STRIPE_SECRET_KEY required');
