import { Pool } from 'pg';
import Stripe from 'stripe';
import { config } from '../config';
import { Payment, PaymentStatus } from '../../../shared/types';

const pool = new Pool({ connectionString: config.databaseUrl });
const stripe = new Stripe(config.stripeSecretKey!, { apiVersion: '2024-12-18.acacia' });

/**
 * Create Stripe Payment Intent
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
    automatic_payment_methods: { enabled: true },
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
 */
export const capturePayment = async (paymentId: string): Promise<Payment> => {
  const payment = await pool.query('SELECT * FROM payments WHERE payment_id = $1', [paymentId]);
  if (payment.rows.length === 0) throw new Error('Payment not found');

  const paymentData = payment.rows[0];

  if (paymentData.status === PaymentStatus.Captured) {
    return paymentData;
  }

  // Confirm payment intent with Stripe
  await stripe.paymentIntents.confirm(paymentData.stripe_payment_intent_id);

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
 * Get payment by booking ID
 */
export const getPaymentByBooking = async (bookingId: string): Promise<Payment | null> => {
  const result = await pool.query('SELECT * FROM payments WHERE booking_id = $1', [bookingId]);
  return result.rows.length > 0 ? result.rows[0] : null;
};

export default { createPaymentIntent, capturePayment, refundPayment, getPaymentByBooking };
