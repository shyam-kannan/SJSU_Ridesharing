import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { requestJson, startTestServer } from './http-test-utils';

const emailService = {
  sendBookingConfirmation: vi.fn(),
  sendPaymentReceipt: vi.fn(),
  sendTripReminder: vi.fn(),
  sendDriverNewBooking: vi.fn(),
  sendCancellationNotice: vi.fn(),
};

vi.mock('../../services/notification-service/src/services/email.service', () => emailService);

let closeServer: (() => Promise<void>) | null = null;

afterEach(async () => {
  if (closeServer) {
    await closeServer();
    closeServer = null;
  }
});

beforeEach(() => {
  Object.values(emailService).forEach((fn) => fn.mockReset());
});

// ── Push / email legacy endpoints ─────────────────────────────────────────────

describe('services/notification-service > legacy push & email endpoints', () => {
  it('stores a push notification and returns it', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const userId = `push-user-${Date.now()}`;

    const res = await requestJson<{ status: string; data: { user_id: string; type: string } }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/push',
      body: {
        user_id: userId,
        title: 'Ride starting',
        message: 'Your driver is 2 minutes away',
      },
    });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data.type).toBe('push');
    expect(res.body.data.user_id).toBe(userId);
  });

  it('legacy email endpoint returns success without sending', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/email',
      body: {
        user_id: 'u-1',
        email: 'rider@sjsu.edu',
        subject: 'Test',
        message: 'Hello',
      },
    });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
  });
});

// ── Individual notification read ──────────────────────────────────────────────

describe('services/notification-service > individual notification read', () => {
  it('marks a specific notification as read', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const userId = `read-user-${Date.now()}`;

    // Create a notification
    const created = await requestJson<{ data: { id: string } }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send',
      body: { user_id: userId, type: 'trip', title: 'Reminder', message: 'Ride soon' },
    });
    const notifId = created.body.data.id;

    // Mark it as read
    const readRes = await requestJson<{ status: string; data: { id: string } }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: `/notifications/user/${userId}/${notifId}/read`,
    });

    expect(readRes.status).toBe(200);
    expect(readRes.body.status).toBe('success');
    expect(readRes.body.data.id).toBe(notifId);

    // Verify unread count is now 0
    const listRes = await requestJson<{ data: { unread_count: number } }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: `/notifications/user/${userId}?unread_only=true`,
    });
    expect(listRes.body.data.unread_count).toBe(0);
  });

  it('returns 404 for an unknown notification id', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/user/nobody/nonexistent-id/read',
    });

    expect(res.status).toBe(404);
    expect(res.body.status).toBe('error');
  });
});

// ── Typed email endpoints ─────────────────────────────────────────────────────

describe('services/notification-service > typed email endpoints — missing email', () => {
  const missingEmailCases = [
    '/notifications/send/payment-receipt',
    '/notifications/send/trip-reminder',
    '/notifications/send/driver-new-booking',
    '/notifications/send/cancellation',
  ];

  for (const path of missingEmailCases) {
    it(`returns 400 when email is absent for ${path}`, async () => {
      const { default: app } = await import('../../services/notification-service/src/app');
      const server = await startTestServer(app);
      closeServer = server.close;

      const res = await requestJson<{ status: string; message: string }>({
        baseUrl: server.baseUrl,
        method: 'POST',
        path,
        body: { name: 'Alice' },
      });

      expect(res.status).toBe(400);
      expect(res.body.status).toBe('error');
      expect(res.body.message).toBe('email is required');
    });
  }
});

describe('services/notification-service > typed email endpoints — successful dispatch', () => {
  it('calls sendPaymentReceipt and returns success', async () => {
    emailService.sendPaymentReceipt.mockResolvedValueOnce(undefined);
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send/payment-receipt',
      body: {
        email: 'rider@sjsu.edu',
        name: 'Alice',
        amount: 9.5,
        origin: 'SJSU',
        destination: 'Caltrain',
        departureTime: '2025-05-01T08:00:00Z',
        paymentId: 'pay-abc',
      },
    });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(emailService.sendPaymentReceipt).toHaveBeenCalledOnce();
  });

  it('calls sendTripReminder and returns success', async () => {
    emailService.sendTripReminder.mockResolvedValueOnce(undefined);
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send/trip-reminder',
      body: {
        email: 'rider@sjsu.edu',
        name: 'Bob',
        origin: 'SJSU',
        destination: 'Downtown',
        departureTime: '2025-05-01T09:00:00Z',
        driverName: 'Carlos',
      },
    });

    expect(res.status).toBe(200);
    expect(emailService.sendTripReminder).toHaveBeenCalledOnce();
  });

  it('calls sendDriverNewBooking and returns success', async () => {
    emailService.sendDriverNewBooking.mockResolvedValueOnce(undefined);
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send/driver-new-booking',
      body: {
        email: 'driver@sjsu.edu',
        driverName: 'Carlos',
        riderName: 'Alice',
        origin: 'SJSU',
        destination: 'Airport',
        departureTime: '2025-05-01T10:00:00Z',
        seats: 1,
      },
    });

    expect(res.status).toBe(200);
    expect(emailService.sendDriverNewBooking).toHaveBeenCalledOnce();
  });

  it('calls sendCancellationNotice and returns success', async () => {
    emailService.sendCancellationNotice.mockResolvedValueOnce(undefined);
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send/cancellation',
      body: {
        email: 'rider@sjsu.edu',
        name: 'Alice',
        origin: 'SJSU',
        destination: 'Milpitas',
        departureTime: '2025-05-01T11:00:00Z',
        bookingId: 'booking-xyz',
      },
    });

    expect(res.status).toBe(200);
    expect(emailService.sendCancellationNotice).toHaveBeenCalledOnce();
  });

  it('returns 500 when the email service throws', async () => {
    emailService.sendBookingConfirmation.mockRejectedValueOnce(new Error('SMTP failure'));
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send/booking-confirmation',
      body: {
        email: 'rider@sjsu.edu',
        riderName: 'Alice',
        origin: 'SJSU',
        destination: 'Diridon',
        departureTime: '2025-05-01T07:00:00Z',
        seats: 1,
        amount: 5.5,
        bookingId: 'bk-001',
      },
    });

    expect(res.status).toBe(500);
    expect(res.body.status).toBe('error');
  });
});

// ── Driver request notification ───────────────────────────────────────────────

describe('services/notification-service > driver-request endpoint', () => {
  it('creates a driver ride-request notification and returns it', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const driverId = `driver-${Date.now()}`;

    const res = await requestJson<{
      status: string;
      data: { type: string; data: { match_id: string; expires_in_seconds: number } };
    }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/driver-request',
      body: {
        driver_id: driverId,
        match_id: 'match-001',
        request_id: 'req-001',
        rider_name: 'Alice',
        rider_rating: 4.8,
        origin: 'SJSU',
        destination: 'Caltrain',
        departure_time: '2025-05-01T08:30:00Z',
      },
    });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data.type).toBe('incoming_ride_request');
    expect(res.body.data.data.match_id).toBe('match-001');
    expect(res.body.data.data.expires_in_seconds).toBe(15);

    // The notification should now appear in the driver's feed
    const feedRes = await requestJson<{ data: { notifications: Array<{ type: string }> } }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: `/notifications/user/${driverId}`,
    });
    expect(feedRes.body.data.notifications[0].type).toBe('incoming_ride_request');
  });

  it('returns 400 when required driver-request fields are missing', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/driver-request',
      body: { driver_id: 'drv-1' }, // missing match_id and request_id
    });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
  });
});

// ── Support issue reporting ───────────────────────────────────────────────────

describe('services/notification-service > support/report-issue endpoint', () => {
  it('reports an issue and returns success', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string; data: { issueType: string } }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/support/report-issue',
      body: {
        userId: 'u-99',
        email: 'reporter@sjsu.edu',
        issueType: 'safety',
        description: 'Driver was speeding',
      },
    });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data.issueType).toBe('safety');
  });

  it('returns 400 when issueType or description is missing', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/support/report-issue',
      body: { issueType: 'safety' }, // missing description
    });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
  });
});

// ── Notification send — missing required fields ───────────────────────────────

describe('services/notification-service > /notifications/send validation', () => {
  it('returns 400 when a required field is missing from generic send', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const res = await requestJson<{ status: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send',
      body: { user_id: 'u-1', type: 'trip' }, // missing title and message
    });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
  });
});
