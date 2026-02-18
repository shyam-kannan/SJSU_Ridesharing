import nodemailer from 'nodemailer';

// MARK: - Transporter

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

const FROM = process.env.FROM_EMAIL || 'LessGo <noreply@lessgo.app>';

function isEmailConfigured(): boolean {
  return !!(process.env.SMTP_USER && process.env.SMTP_PASS);
}

// MARK: - HTML Template helpers

function baseTemplate(content: string): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LessGo</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #F5F5F7; margin: 0; padding: 20px; }
    .card { background: white; border-radius: 16px; max-width: 560px; margin: 0 auto; padding: 32px; box-shadow: 0 2px 16px rgba(0,0,0,0.08); }
    .header { text-align: center; margin-bottom: 28px; }
    .logo { font-size: 28px; font-weight: 800; color: #4F46E5; letter-spacing: -0.5px; }
    .badge { display: inline-block; background: #EEF2FF; color: #4F46E5; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; margin-top: 6px; }
    h2 { color: #1C1C1E; font-size: 20px; margin: 0 0 16px; }
    p { color: #3C3C43; font-size: 15px; line-height: 1.6; margin: 0 0 12px; }
    .detail-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #F2F2F7; }
    .detail-label { color: #8E8E93; font-size: 13px; }
    .detail-value { color: #1C1C1E; font-size: 13px; font-weight: 600; }
    .amount { font-size: 28px; font-weight: 800; color: #4F46E5; text-align: center; margin: 16px 0; }
    .footer { text-align: center; color: #8E8E93; font-size: 12px; margin-top: 24px; }
    .green { color: #34C759; }
    .orange { color: #FF9500; }
    .red { color: #FF3B30; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="logo">LessGo 🚗</div>
      <div class="badge">SJSU Ridesharing</div>
    </div>
    ${content}
    <div class="footer">
      <p>LessGo — Safe, sustainable carpooling for SJSU students</p>
      <p>San José State University · San José, CA 95192</p>
    </div>
  </div>
</body>
</html>`;
}

// MARK: - Email Senders

export async function sendBookingConfirmation(
  to: string,
  data: { riderName: string; origin: string; destination: string; departureTime: string; seats: number; amount: number; bookingId: string }
): Promise<void> {
  if (!isEmailConfigured()) {
    console.log(`[EMAIL STUB] Booking confirmation to ${to} – booking ${data.bookingId}`);
    return;
  }

  const html = baseTemplate(`
    <h2>✅ Booking Confirmed!</h2>
    <p>Hi ${data.riderName}, your seat is reserved. Here's your booking summary:</p>
    <div class="detail-row"><span class="detail-label">From</span><span class="detail-value">${data.origin}</span></div>
    <div class="detail-row"><span class="detail-label">To</span><span class="detail-value">${data.destination}</span></div>
    <div class="detail-row"><span class="detail-label">Departure</span><span class="detail-value">${data.departureTime}</span></div>
    <div class="detail-row"><span class="detail-label">Seats</span><span class="detail-value">${data.seats}</span></div>
    <div class="detail-row"><span class="detail-label">Booking ID</span><span class="detail-value">${data.bookingId.slice(0, 8).toUpperCase()}</span></div>
    <div class="amount">$${data.amount.toFixed(2)}</div>
    <p style="text-align:center;color:#8E8E93;font-size:13px;">Total charged to your payment method</p>
  `);

  await transporter.sendMail({ from: FROM, to, subject: '✅ Your LessGo Ride is Confirmed!', html });
}

export async function sendPaymentReceipt(
  to: string,
  data: { name: string; amount: number; origin: string; destination: string; departureTime: string; paymentId: string }
): Promise<void> {
  if (!isEmailConfigured()) {
    console.log(`[EMAIL STUB] Payment receipt to ${to} – payment ${data.paymentId}`);
    return;
  }

  const html = baseTemplate(`
    <h2>💳 Payment Receipt</h2>
    <p>Hi ${data.name}, your payment was processed successfully.</p>
    <div class="detail-row"><span class="detail-label">Route</span><span class="detail-value">${data.origin} → ${data.destination}</span></div>
    <div class="detail-row"><span class="detail-label">Departure</span><span class="detail-value">${data.departureTime}</span></div>
    <div class="detail-row"><span class="detail-label">Payment ID</span><span class="detail-value">${data.paymentId.slice(0, 8).toUpperCase()}</span></div>
    <div class="detail-row"><span class="detail-label">Status</span><span class="detail-value green">Captured</span></div>
    <div class="amount">$${data.amount.toFixed(2)}</div>
    <p style="text-align:center;color:#8E8E93;font-size:13px;">This is your official receipt. Keep it for your records.</p>
  `);

  await transporter.sendMail({ from: FROM, to, subject: '💳 LessGo Payment Receipt', html });
}

export async function sendTripReminder(
  to: string,
  data: { name: string; origin: string; destination: string; departureTime: string; driverName: string; vehicleInfo?: string }
): Promise<void> {
  if (!isEmailConfigured()) {
    console.log(`[EMAIL STUB] Trip reminder to ${to}`);
    return;
  }

  const html = baseTemplate(`
    <h2>⏰ Trip Starting Soon!</h2>
    <p>Hi ${data.name}, your ride departs in about 1 hour. Here's a quick reminder:</p>
    <div class="detail-row"><span class="detail-label">From</span><span class="detail-value">${data.origin}</span></div>
    <div class="detail-row"><span class="detail-label">To</span><span class="detail-value">${data.destination}</span></div>
    <div class="detail-row"><span class="detail-label">Departure</span><span class="detail-value orange">${data.departureTime}</span></div>
    <div class="detail-row"><span class="detail-label">Driver</span><span class="detail-value">${data.driverName}</span></div>
    ${data.vehicleInfo ? `<div class="detail-row"><span class="detail-label">Vehicle</span><span class="detail-value">${data.vehicleInfo}</span></div>` : ''}
    <p>Please be at the pickup location 5 minutes early. Open LessGo to see your driver's location.</p>
  `);

  await transporter.sendMail({ from: FROM, to, subject: '⏰ Your LessGo Ride Starts in 1 Hour', html });
}

export async function sendDriverNewBooking(
  to: string,
  data: { driverName: string; riderName: string; origin: string; destination: string; departureTime: string; seats: number }
): Promise<void> {
  if (!isEmailConfigured()) {
    console.log(`[EMAIL STUB] New booking notification to driver ${to}`);
    return;
  }

  const html = baseTemplate(`
    <h2>🎉 New Passenger Booked!</h2>
    <p>Hi ${data.driverName}, a rider just confirmed a seat on your trip.</p>
    <div class="detail-row"><span class="detail-label">Rider</span><span class="detail-value">${data.riderName}</span></div>
    <div class="detail-row"><span class="detail-label">From</span><span class="detail-value">${data.origin}</span></div>
    <div class="detail-row"><span class="detail-label">To</span><span class="detail-value">${data.destination}</span></div>
    <div class="detail-row"><span class="detail-label">Departure</span><span class="detail-value">${data.departureTime}</span></div>
    <div class="detail-row"><span class="detail-label">Seats Booked</span><span class="detail-value">${data.seats}</span></div>
    <p>Open LessGo to see full passenger details.</p>
  `);

  await transporter.sendMail({ from: FROM, to, subject: '🎉 New Passenger on Your LessGo Trip!', html });
}

export async function sendCancellationNotice(
  to: string,
  data: { name: string; origin: string; destination: string; departureTime: string; refundAmount?: number; bookingId: string }
): Promise<void> {
  if (!isEmailConfigured()) {
    console.log(`[EMAIL STUB] Cancellation notice to ${to} – booking ${data.bookingId}`);
    return;
  }

  const refundLine = data.refundAmount
    ? `<div class="detail-row"><span class="detail-label">Refund</span><span class="detail-value green">$${data.refundAmount.toFixed(2)} (3–5 business days)</span></div>`
    : '';

  const html = baseTemplate(`
    <h2>❌ Booking Cancelled</h2>
    <p>Hi ${data.name}, your booking has been cancelled.</p>
    <div class="detail-row"><span class="detail-label">Route</span><span class="detail-value">${data.origin} → ${data.destination}</span></div>
    <div class="detail-row"><span class="detail-label">Departure</span><span class="detail-value">${data.departureTime}</span></div>
    <div class="detail-row"><span class="detail-label">Booking ID</span><span class="detail-value">${data.bookingId.slice(0, 8).toUpperCase()}</span></div>
    ${refundLine}
    <p>Browse LessGo for other available trips at your time.</p>
  `);

  await transporter.sendMail({ from: FROM, to, subject: '❌ LessGo Booking Cancelled', html });
}
