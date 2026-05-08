import { Router, Request, Response } from 'express';

const router = Router();

const stripePublishableKey = process.env.STRIPE_PUBLISHABLE_KEY || '';

router.get('/stripe', (_req: Request, res: Response) => {
  res.json({
    status: 'success',
    data: { publishableKey: stripePublishableKey },
  });
});

export default router;
