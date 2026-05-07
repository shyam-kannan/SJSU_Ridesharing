import { beforeEach, describe, expect, it, vi } from 'vitest';

const nodemailerMocks = vi.hoisted(() => ({
  createTransport: vi.fn(),
  sendMail: vi.fn(),
}));

vi.mock('nodemailer', () => ({
  default: {
    createTransport: nodemailerMocks.createTransport,
  },
}));

async function importEmailService() {
  vi.resetModules();
  nodemailerMocks.sendMail.mockReset();
  nodemailerMocks.createTransport.mockReset().mockReturnValue({
    sendMail: nodemailerMocks.sendMail,
  });

  return import('../../services/notification-service/src/services/email.service');
}

beforeEach(() => {
  delete process.env.SMTP_USER;
  delete process.env.SMTP_PASS;
  delete process.env.FROM_EMAIL;
});

describe('services/notification-service email.service', () => {
  it('falls back to stub logging when SMTP credentials are missing', async () => {
    const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
    const emailService = await importEmailService();

    await emailService.sendBookingConfirmation('rider@sjsu.edu', {
      amount: 14.5,
      bookingId: 'booking-12345678',
      departureTime: '2026-05-10T08:00:00Z',
      destination: 'SJSU',
      origin: 'San Francisco',
      riderName: 'Alex',
      seats: 1,
    });

    expect(nodemailerMocks.sendMail).not.toHaveBeenCalled();
    expect(consoleSpy).toHaveBeenCalledWith(
      '[EMAIL STUB] Booking confirmation to rider@sjsu.edu – booking booking-12345678'
    );

    consoleSpy.mockRestore();
  });

  it('sends a formatted payment receipt email when SMTP is configured', async () => {
    process.env.SMTP_USER = 'mailer@sjsu.edu';
    process.env.SMTP_PASS = 'smtp-password';
    process.env.FROM_EMAIL = 'LessGo Test <test@lessgo.app>';

    const emailService = await importEmailService();

    await emailService.sendPaymentReceipt('rider@sjsu.edu', {
      amount: 18,
      departureTime: '2026-05-10 08:00 AM',
      destination: 'SJSU',
      name: 'Alex',
      origin: 'San Francisco',
      paymentId: 'pay_1234567890',
    });

    expect(nodemailerMocks.createTransport).toHaveBeenCalledTimes(1);
    expect(nodemailerMocks.sendMail).toHaveBeenCalledWith(
      expect.objectContaining({
        from: 'LessGo Test <test@lessgo.app>',
        subject: '💳 LessGo Payment Receipt',
        to: 'rider@sjsu.edu',
      })
    );

    const sentEmail = nodemailerMocks.sendMail.mock.calls[0][0];
    expect(sentEmail.html).toContain('San Francisco → SJSU');
    expect(sentEmail.html).toContain('PAY_1234');
    expect(sentEmail.html).toContain('$18.00');
    expect(sentEmail.html).toContain('Payment Receipt');
  });

  it('renders the optional vehicle row in trip reminders only when vehicle info is provided', async () => {
    process.env.SMTP_USER = 'mailer@sjsu.edu';
    process.env.SMTP_PASS = 'smtp-password';

    const emailService = await importEmailService();

    await emailService.sendTripReminder('rider@sjsu.edu', {
      departureTime: '2026-05-10 08:00 AM',
      destination: 'SJSU',
      driverName: 'Jordan',
      name: 'Alex',
      origin: 'Downtown San Jose',
      vehicleInfo: 'Blue Tesla Model 3',
    });

    const withVehicle = nodemailerMocks.sendMail.mock.calls[0][0];
    expect(withVehicle.subject).toBe('⏰ Your LessGo Ride Starts in 1 Hour');
    expect(withVehicle.html).toContain('Blue Tesla Model 3');

    nodemailerMocks.sendMail.mockClear();

    await emailService.sendTripReminder('rider@sjsu.edu', {
      departureTime: '2026-05-10 08:00 AM',
      destination: 'SJSU',
      driverName: 'Jordan',
      name: 'Alex',
      origin: 'Downtown San Jose',
    });

    const withoutVehicle = nodemailerMocks.sendMail.mock.calls[0][0];
    expect(withoutVehicle.html).not.toContain('Vehicle</span>');
  });

  it('includes refund details in cancellation emails when a refund amount is present', async () => {
    process.env.SMTP_USER = 'mailer@sjsu.edu';
    process.env.SMTP_PASS = 'smtp-password';

    const emailService = await importEmailService();

    await emailService.sendCancellationNotice('rider@sjsu.edu', {
      bookingId: 'booking-abcdef12',
      departureTime: '2026-05-10 08:00 AM',
      destination: 'SJSU',
      name: 'Alex',
      origin: 'Palo Alto',
      refundAmount: 12.75,
    });

    const sentEmail = nodemailerMocks.sendMail.mock.calls[0][0];
    expect(sentEmail.subject).toBe('❌ LessGo Booking Cancelled');
    expect(sentEmail.html).toContain('Refund');
    expect(sentEmail.html).toContain('$12.75');
    expect(sentEmail.html).toContain('BOOKING-');
  });
});
