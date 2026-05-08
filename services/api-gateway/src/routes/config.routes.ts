import { Router, Request, Response } from 'express';

const router = Router();

const stripePublishableKey = process.env.STRIPE_PUBLISHABLE_KEY || '';
if (!stripePublishableKey) {
  console.warn('[config] STRIPE_PUBLISHABLE_KEY is not set — Stripe will fail on the client');
}

router.get('/stripe', (_req: Request, res: Response) => {
  res.json({
    status: 'success',
    data: { publishableKey: stripePublishableKey },
  });
});

export default router;
