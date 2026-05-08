import express, { Application } from 'express';
import cors from 'cors';
import * as emailService from './services/email.service';

const app: Application = express();
app.use(express.json());
app.use(cors());

type InAppNotification = {
  id: string;
  user_id: string;
  type: string;
  title: string;
  message: string;
  data?: Record<string, any>;
  created_at: string;
  read_at: string | null;
};

const notificationStore = new Map<string, InAppNotification[]>();

function createNotification(input: Omit<InAppNotification, 'id' | 'created_at' | 'read_at'>): InAppNotification {
  return {
    id: `notif_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
    created_at: new Date().toISOString(),
    read_at: null,
    ...input,
  };
}

function pushNotification(notification: InAppNotification): void {
  const current = notificationStore.get(notification.user_id) ?? [];
  current.unshift(notification);
  // Keep only the most recent 200 notifications per user to avoid unbounded memory growth.
  notificationStore.set(notification.user_id, current.slice(0, 200));
}

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
  const notification = createNotification({ user_id, type, title, message, data });
  pushNotification(notification);
  res.json({ status: 'success', message: 'Notification sent', data: notification });
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
  const notification = createNotification({ user_id, type: 'push', title, message, data });
  pushNotification(notification);
  res.json({ status: 'success', message: 'Push notification queued', data: notification });
});

// In-app notification feed
app.get('/notifications/user/:userId', (req, res) => {
  const { userId } = req.params;
  const unreadOnly = req.query.unread_only === 'true';
  const limit = Math.max(1, Math.min(100, parseInt(String(req.query.limit || '50'), 10) || 50));

  const items = notificationStore.get(userId) ?? [];
  const filtered = unreadOnly ? items.filter((n) => n.read_at === null) : items;
  const notifications = filtered.slice(0, limit);
  const unreadCount = items.filter((n) => n.read_at === null).length;

  res.json({
    status: 'success',
    message: 'Notifications retrieved',
    data: { notifications, total: filtered.length, unread_count: unreadCount }
  });
});

app.post('/notifications/user/:userId/read-all', (req, res) => {
  const { userId } = req.params;
  const items = notificationStore.get(userId) ?? [];
  const now = new Date().toISOString();

  const updated = items.map((n) => (n.read_at ? n : { ...n, read_at: now }));
  notificationStore.set(userId, updated);

  res.json({
    status: 'success',
    message: 'All notifications marked as read',
    data: { user_id: userId, marked: items.filter((n) => !n.read_at).length }
  });
});

app.post('/notifications/user/:userId/:notificationId/read', (req, res) => {
  const { userId, notificationId } = req.params;
  const items = notificationStore.get(userId) ?? [];
  let updatedOne = false;

  const updated = items.map((n) => {
    if (n.id !== notificationId) return n;
    updatedOne = true;
    return n.read_at ? n : { ...n, read_at: new Date().toISOString() };
  });
  notificationStore.set(userId, updated);

  if (!updatedOne) {
    res.status(404).json({ status: 'error', message: 'Notification not found' });
    return;
  }

  res.json({ status: 'success', message: 'Notification marked as read', data: { id: notificationId } });
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

// ─── Driver ride-request notification ────────────────────────────────────────

/**
 * POST /notifications/driver-request
 * Body: { driver_id, match_id, request_id, rider_name, rider_rating,
 *         origin, destination, departure_time }
 *
 * Pushes a structured in-app notification to the driver so the iOS app can
 * surface the incoming-request card with the 15-second countdown.
 */
app.post('/notifications/driver-request', (req, res) => {
  const {
    driver_id, match_id, request_id, trip_id,
    rider_name, rider_rating,
    origin, destination, departure_time,
  } = req.body;

  if (!driver_id || !match_id || !request_id) {
    res.status(400).json({ status: 'error', message: 'driver_id, match_id, and request_id are required' });
    return;
  }

  const notification = createNotification({
    user_id: driver_id,
    type: 'incoming_ride_request',
    title: `Ride request from ${rider_name ?? 'Rider'}`,
    message: `${origin} → ${destination}`,
    data: {
      match_id,
      request_id,
      trip_id:       trip_id      ?? null,
      rider_name:    rider_name   ?? 'Rider',
      rider_rating:  rider_rating ?? 5.0,
      origin,
      destination,
      departure_time,
      expires_in_seconds: 15,
    },
  });

  pushNotification(notification);
  console.log(`[DRIVER-REQUEST] driver=${driver_id} match=${match_id} rider="${rider_name}" ${origin}→${destination}`);
  res.json({ status: 'success', message: 'Driver request notification sent', data: notification });
});

// ─── Payment deadline cancellation notifications ──────────────────────────────

/**
 * POST /notifications/send/payment-deadline-cancelled
 * Body: {
 *   rider_id, rider_email,
 *   driver_id,
 *   other_passenger_ids: string[],
 *   trip_origin, trip_destination, departure_time
 * }
 *
 * Sends:
 *   - Rider: in-app + email — booking cancelled because payment not completed.
 *   - Driver: in-app — passenger removed, route updated.
 *   - Other passengers: in-app — route updated.
 */
app.post('/notifications/send/payment-deadline-cancelled', async (req, res) => {
  const {
    rider_id,
    rider_email,
    driver_id,
    other_passenger_ids,
    trip_origin,
    trip_destination,
    departure_time,
  } = req.body;

  if (!rider_id || !driver_id) {
    res.status(400).json({ status: 'error', message: 'rider_id and driver_id are required' });
    return;
  }

  const departureStr = departure_time
    ? new Date(departure_time).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })
    : 'your scheduled trip';

  // Notify rider in-app
  const riderNotification = createNotification({
    user_id: rider_id,
    type: 'booking_cancelled_payment_deadline',
    title: 'Booking Cancelled',
    message: `Your booking for ${trip_origin} → ${trip_destination} was cancelled because payment wasn't completed before the deadline.`,
    data: { trip_origin, trip_destination, departure_time },
  });
  pushNotification(riderNotification);

  // Notify rider via email (non-fatal)
  if (rider_email) {
    try {
      await emailService.sendCancellationNotice(rider_email, {
        name: 'Rider',
        origin: trip_origin ?? '',
        destination: trip_destination ?? '',
        departureTime: departureStr,
        bookingId: 'deadline-cancellation',
      });
    } catch (err) {
      console.warn('[payment-deadline-cancelled] Rider email failed (non-fatal):', err);
    }
  }

  // Notify driver in-app
  const driverNotification = createNotification({
    user_id: driver_id,
    type: 'passenger_removed_payment_deadline',
    title: 'Passenger Removed',
    message: `A passenger was removed from your trip (${trip_origin} → ${trip_destination}) — payment not completed. Your route has been updated.`,
    data: { trip_origin, trip_destination, departure_time },
  });
  pushNotification(driverNotification);

  // Notify other passengers in-app
  const otherIds: string[] = Array.isArray(other_passenger_ids) ? other_passenger_ids : [];
  for (const passengerId of otherIds) {
    const passengerNotification = createNotification({
      user_id: passengerId,
      type: 'route_updated',
      title: 'Route Updated',
      message: `Your pickup route for the trip on ${departureStr} has been updated.`,
      data: { trip_origin, trip_destination, departure_time },
    });
    pushNotification(passengerNotification);
  }

  console.log(
    `[payment-deadline-cancelled] rider=${rider_id} driver=${driver_id} others=${otherIds.length}`
  );

  res.json({
    status: 'success',
    message: 'Payment deadline cancellation notifications sent',
    data: {
      rider_notified: true,
      rider_email_notified: !!rider_email,
      driver_notified: true,
      other_passengers_notified: otherIds.length,
    },
  });
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
