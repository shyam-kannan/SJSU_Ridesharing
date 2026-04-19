import dotenv from 'dotenv';
import { getSecretValue } from '@lessgo/shared';

dotenv.config();

export const config = {
  port: process.env.PAYMENT_SERVICE_PORT || 3005,
  env: process.env.NODE_ENV || 'development',
  databaseUrl: getSecretValue('DATABASE_URL'),
  stripeSecretKey: getSecretValue('STRIPE_SECRET_KEY'),
  stripeWebhookSecret: getSecretValue('STRIPE_WEBHOOK_SECRET'),
};

if (!config.databaseUrl) throw new Error('DATABASE_URL required');
if (!config.stripeSecretKey) throw new Error('STRIPE_SECRET_KEY required');
