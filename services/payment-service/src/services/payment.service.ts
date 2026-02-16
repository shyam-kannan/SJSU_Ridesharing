import { Pool } from 'pg';
import Stripe from 'stripe';
import { config } from '../config';
import { Payment, PaymentStatus } from '@lessgo/shared';

const pool = new Pool({ connectionString: config.databaseUrl });
const stripe = new Stripe(config.stripeSecretKey!);

/**
 * Create Stripe Payment Intent
 * Uses manual capture so the iOS app can confirm, then we capture server-side.
 */
export const createPaymentIntent = async (
  bookingId: string,
  amount: number
): Promise<Payment> => {
  // Check if payment already exists for booking
  const existing = await pool.query('SELECT * FROM payments WHERE booking_id = $1', [bookingId]);
  if (existing.rows.length > 0) {
    throw new Error('Payment already exists for this booking');
  }

  // Create Stripe Payment Intent
  const paymentIntent = await stripe.paymentIntents.create({
    amount: Math.round(amount * 100), // Convert to cents
    currency: 'usd',
    capture_method: 'manual',
    metadata: { booking_id: bookingId },
  });

  // Store payment record
  const query = `
    INSERT INTO payments (booking_id, stripe_payment_intent_id, amount, status)
    VALUES ($1, $2, $3, $4)
    RETURNING *
  `;
  const result = await pool.query(query, [
    bookingId,
    paymentIntent.id,
    amount,
    PaymentStatus.Pending,
  ]);

  return result.rows[0];
};

/**
 * Capture payment
 * In production: the iOS app confirms the PaymentIntent first, then this captures it.
 * In test mode: capture/refund require manual confirmation which isn't available server-side.
 */
export const capturePayment = async (paymentId: string): Promise<Payment> => {
  const payment = await pool.query('SELECT * FROM payments WHERE payment_id = $1', [paymentId]);
  if (payment.rows.length === 0) throw new Error('Payment not found');

  const paymentData = payment.rows[0];

  if (paymentData.status === PaymentStatus.Captured) {
    return paymentData;
  }

  const stripeIntentId = paymentData.stripe_payment_intent_id;
  const paymentIntent = await stripe.paymentIntents.retrieve(stripeIntentId);

  if (paymentIntent.status === 'requires_capture') {
    await stripe.paymentIntents.capture(stripeIntentId);
  } else if (paymentIntent.status === 'succeeded') {
    // Already captured on Stripe side
  } else {
    throw new Error(`Cannot capture payment in state: ${paymentIntent.status}. Client must confirm the PaymentIntent first.`);
  }

  // Update status
  const updateQuery = `
    UPDATE payments SET status = $1, updated_at = current_timestamp
    WHERE payment_id = $2 RETURNING *
  `;
  const result = await pool.query(updateQuery, [PaymentStatus.Captured, paymentId]);
  return result.rows[0];
};

/**
 * Refund payment
 */
export const refundPayment = async (paymentId: string): Promise<Payment> => {
  const payment = await pool.query('SELECT * FROM payments WHERE payment_id = $1', [paymentId]);
  if (payment.rows.length === 0) throw new Error('Payment not found');

  const paymentData = payment.rows[0];

  if (paymentData.status !== PaymentStatus.Captured) {
    throw new Error('Can only refund captured payments');
  }

  // Create refund with Stripe
  await stripe.refunds.create({ payment_intent: paymentData.stripe_payment_intent_id });

  // Update status
  const updateQuery = `
    UPDATE payments SET status = $1, updated_at = current_timestamp
    WHERE payment_id = $2 RETURNING *
  `;
  const result = await pool.query(updateQuery, [PaymentStatus.Refunded, paymentId]);
  return result.rows[0];
};

/**
 * Cancel a pending payment (cancels the Stripe PaymentIntent)
 */
export const cancelPayment = async (paymentId: string): Promise<Payment> => {
  const payment = await pool.query('SELECT * FROM payments WHERE payment_id = $1', [paymentId]);
  if (payment.rows.length === 0) throw new Error('Payment not found');

  const paymentData = payment.rows[0];

  if (paymentData.status !== PaymentStatus.Pending) {
    throw new Error('Can only cancel pending payments');
  }

  // Cancel PaymentIntent with Stripe
  await stripe.paymentIntents.cancel(paymentData.stripe_payment_intent_id);

  // Update status
  const updateQuery = `
    UPDATE payments SET status = $1, updated_at = current_timestamp
    WHERE payment_id = $2 RETURNING *
  `;
  const result = await pool.query(updateQuery, [PaymentStatus.Failed, paymentId]);
  return result.rows[0];
};

/**
 * Get payment by booking ID
 */
export const getPaymentByBooking = async (bookingId: string): Promise<Payment | null> => {
  const result = await pool.query('SELECT * FROM payments WHERE booking_id = $1', [bookingId]);
  return result.rows.length > 0 ? result.rows[0] : null;
};

export default { createPaymentIntent, capturePayment, refundPayment, cancelPayment, getPaymentByBooking };
