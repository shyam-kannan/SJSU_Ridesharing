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

describe('services/notification-service/src/app', () => {
  it('returns health information', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; service: string }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: '/health',
    });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.service).toBe('notification-service');
  });

  it('stores and returns in-app notifications for a user', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const userId = `user-${Date.now()}`;

    const createResponse = await requestJson<{ status: string; data: { user_id: string } }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send',
      body: {
        user_id: userId,
        type: 'booking',
        title: 'Booking Confirmed',
        message: 'Your booking is complete',
      },
    });

    expect(createResponse.status).toBe(200);
    expect(createResponse.body.status).toBe('success');
    expect(createResponse.body.data.user_id).toBe(userId);

    const listResponse = await requestJson<{
      status: string;
      data: { notifications: Array<{ id: string; read_at: string | null }>; unread_count: number };
    }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: `/notifications/user/${userId}`,
    });

    expect(listResponse.status).toBe(200);
    expect(listResponse.body.data.notifications).toHaveLength(1);
    expect(listResponse.body.data.unread_count).toBe(1);
  });

  it('marks notifications as read and supports unread-only filtering', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const userId = `user-${Date.now()}-read`;
    await requestJson({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send',
      body: {
        user_id: userId,
        type: 'trip',
        title: 'Trip Reminder',
        message: 'Trip starts soon',
      },
    });

    const beforeRead = await requestJson<{ data: { unread_count: number } }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: `/notifications/user/${userId}?unread_only=true`,
    });
    expect(beforeRead.body.data.unread_count).toBe(1);

    const markAll = await requestJson<{ status: string; data: { marked: number } }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: `/notifications/user/${userId}/read-all`,
    });
    expect(markAll.status).toBe(200);
    expect(markAll.body.data.marked).toBe(1);

    const afterRead = await requestJson<{ data: { notifications: unknown[]; unread_count: number } }>({
      baseUrl: server.baseUrl,
      method: 'GET',
      path: `/notifications/user/${userId}?unread_only=true`,
    });
    expect(afterRead.body.data.notifications).toHaveLength(0);
    expect(afterRead.body.data.unread_count).toBe(0);
  });

  it('returns 400 when booking-confirmation email endpoint is missing email', async () => {
    const { default: app } = await import('../../services/notification-service/src/app');
    const server = await startTestServer(app);
    closeServer = server.close;

    const response = await requestJson<{ status: string; message: string }>({
      baseUrl: server.baseUrl,
      method: 'POST',
      path: '/notifications/send/booking-confirmation',
      body: {
        riderName: 'Alex',
      },
    });

    expect(response.status).toBe(400);
    expect(response.body.status).toBe('error');
    expect(emailService.sendBookingConfirmation).not.toHaveBeenCalled();
  });
});
