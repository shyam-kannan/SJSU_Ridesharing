import express, { Application } from 'express';
import cors from 'cors';
import * as emailService from './services/email.service';

const app: Application = express();
app.use(express.json());
app.use(cors());

// Health check
app.get('/health', (_req, res) => {
  res.json({
    status: 'success',
    message: 'Notification Service is running',
    service: 'notification-service',
    timestamp: new Date().toISOString(),
  });
});

// ─── Legacy generic endpoints (keep for backward compatibility) ───────────────

app.post('/notifications/send', (req, res) => {
  const { user_id, type, title, message, data } = req.body;
  if (!user_id || !type || !title || !message) {
    res.status(400).json({ status: 'error', message: 'user_id, type, title, and message are required' });
    return;
  }
  console.log(`[NOTIFICATION] type=${type} user=${user_id} title="${title}" message="${message}"`);
  if (data) console.log(`  data=${JSON.stringify(data)}`);
  res.json({ status: 'success', message: 'Notification sent', data: { user_id, type, title } });
});

app.post('/notifications/email', (req, res) => {
  const { user_id, email, subject, message, data } = req.body;
  console.log(`[EMAIL] to=${email} user=${user_id} subject="${subject}"`);
  if (data) console.log(`  data=${JSON.stringify(data)}`);
  res.json({ status: 'success', message: 'Email notification queued', data: { user_id, email, subject } });
});

app.post('/notifications/push', (req, res) => {
  const { user_id, title, message, data } = req.body;
  console.log(`[PUSH] user=${user_id} title="${title}" message="${message}"`);
  if (data) console.log(`  data=${JSON.stringify(data)}`);
  res.json({ status: 'success', message: 'Push notification queued', data: { user_id, title } });
});

// ─── Typed email endpoints ───────────────────────────────────────────────────

/**
 * POST /notifications/send/booking-confirmation
 * Body: { email, riderName, origin, destination, departureTime, seats, amount, bookingId }
 */
app.post('/notifications/send/booking-confirmation', async (req, res) => {
  const { email, ...data } = req.body;
  if (!email) { res.status(400).json({ status: 'error', message: 'email is required' }); return; }
  try {
    await emailService.sendBookingConfirmation(email, data);
    res.json({ status: 'success', message: 'Booking confirmation email sent', data: { email } });
  } catch (err) {
    console.error('[EMAIL] booking-confirmation error:', err);
    res.status(500).json({ status: 'error', message: 'Failed to send email' });
  }
});

/**
 * POST /notifications/send/payment-receipt
 * Body: { email, name, amount, origin, destination, departureTime, paymentId }
 */
app.post('/notifications/send/payment-receipt', async (req, res) => {
  const { email, ...data } = req.body;
  if (!email) { res.status(400).json({ status: 'error', message: 'email is required' }); return; }
  try {
    await emailService.sendPaymentReceipt(email, data);
    res.json({ status: 'success', message: 'Payment receipt email sent', data: { email } });
  } catch (err) {
    console.error('[EMAIL] payment-receipt error:', err);
    res.status(500).json({ status: 'error', message: 'Failed to send email' });
  }
});

/**
 * POST /notifications/send/trip-reminder
 * Body: { email, name, origin, destination, departureTime, driverName, vehicleInfo? }
 */
app.post('/notifications/send/trip-reminder', async (req, res) => {
  const { email, ...data } = req.body;
  if (!email) { res.status(400).json({ status: 'error', message: 'email is required' }); return; }
  try {
    await emailService.sendTripReminder(email, data);
    res.json({ status: 'success', message: 'Trip reminder email sent', data: { email } });
  } catch (err) {
    console.error('[EMAIL] trip-reminder error:', err);
    res.status(500).json({ status: 'error', message: 'Failed to send email' });
  }
});

/**
 * POST /notifications/send/driver-new-booking
 * Body: { email, driverName, riderName, origin, destination, departureTime, seats }
 */
app.post('/notifications/send/driver-new-booking', async (req, res) => {
  const { email, ...data } = req.body;
  if (!email) { res.status(400).json({ status: 'error', message: 'email is required' }); return; }
  try {
    await emailService.sendDriverNewBooking(email, data);
    res.json({ status: 'success', message: 'Driver notification email sent', data: { email } });
  } catch (err) {
    console.error('[EMAIL] driver-new-booking error:', err);
    res.status(500).json({ status: 'error', message: 'Failed to send email' });
  }
});

/**
 * POST /notifications/send/cancellation
 * Body: { email, name, origin, destination, departureTime, refundAmount?, bookingId }
 */
app.post('/notifications/send/cancellation', async (req, res) => {
  const { email, ...data } = req.body;
  if (!email) { res.status(400).json({ status: 'error', message: 'email is required' }); return; }
  try {
    await emailService.sendCancellationNotice(email, data);
    res.json({ status: 'success', message: 'Cancellation email sent', data: { email } });
  } catch (err) {
    console.error('[EMAIL] cancellation error:', err);
    res.status(500).json({ status: 'error', message: 'Failed to send email' });
  }
});

// ─── Support endpoints ────────────────────────────────────────────────────────

/**
 * POST /support/report-issue
 * Body: { userId?, email?, issueType, description }
 */
app.post('/support/report-issue', (req, res) => {
  const { userId, email, issueType, description } = req.body;
  if (!issueType || !description) {
    res.status(400).json({ status: 'error', message: 'issueType and description are required' });
    return;
  }
  console.log(`[SUPPORT] Issue reported`);
  console.log(`  Type: ${issueType}`);
  console.log(`  User: ${userId || 'anonymous'}`);
  console.log(`  Email: ${email || 'not provided'}`);
  console.log(`  Description: ${description}`);
  res.json({ status: 'success', message: 'Issue reported successfully', data: { issueType } });
});

export default app;
